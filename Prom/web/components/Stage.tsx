"use client";

import { motion } from "motion/react";
import type { ReactNode } from "react";

type StageKind = "gate" | "ask" | "yes" | "no";

const BG: Record<StageKind, string> = {
  gate: "stage-gate",
  ask: "stage-ask",
  yes: "stage-yes",
  no: "stage-no",
};

type Props = {
  kind: StageKind;
  children: ReactNode;
  /** bottom-left copy block (gate) vs centered (everything else) */
  align?: "center" | "bottom-left";
};

/**
 * Full-viewport backdrop for one screen: gradient stand-in for the photo,
 * drifting bokeh, grain and a vignette, with the content slotted on top.
 * Cross-fades itself in/out via AnimatePresence in the parent.
 */
export default function Stage({ kind, children, align = "center" }: Props) {
  const warm = kind !== "no";

  return (
    <motion.div
      key={kind}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
      className={`grain vignette ${kind === "no" ? "vignette--heavy" : ""} ${BG[kind]} fixed inset-0 overflow-hidden`}
    >
      {warm && <div className={`bokeh ${kind === "gate" ? "bokeh--dim" : ""}`} />}

      <div
        className={
          align === "bottom-left"
            ? "relative z-10 flex min-h-dvh w-full items-end justify-center px-6 pb-14 sm:justify-start sm:px-14 sm:pb-16 lg:px-20"
            : "relative z-10 flex min-h-dvh w-full items-center justify-center px-6 py-14"
        }
      >
        {children}
      </div>
    </motion.div>
  );
}
