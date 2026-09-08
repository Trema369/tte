"use client";

import { useMemo } from "react";
import { motion, useReducedMotion } from "motion/react";
import HeartDivider from "./HeartDivider";

const PROM_DATE = "13 November 2026";

export default function YesResult() {
  const reduce = useReducedMotion();

  const hearts = useMemo(
    () =>
      Array.from({ length: 14 }, (_, i) => ({
        id: i,
        left: Math.random() * 100,
        delay: Math.random() * 8,
        dur: 7 + Math.random() * 6,
        size: 10 + Math.random() * 16,
        opacity: 0.25 + Math.random() * 0.4,
      })),
    [],
  );

  return (
    <div className="relative w-full max-w-lg text-center text-ink">
      {!reduce && (
        <div className="pointer-events-none fixed inset-0 overflow-hidden">
          {hearts.map((h) => (
            <span
              key={h.id}
              className="absolute bottom-[-40px]"
              style={{
                left: `${h.left}%`,
                width: h.size,
                height: h.size,
                opacity: h.opacity,
                color: "#c2415f",
                animation: `rise ${h.dur}s linear ${h.delay}s infinite`,
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor" className="h-full w-full">
                <path d="M12 21s-6.7-4.35-9.33-8.24C.9 9.9 2.02 6.2 5.2 5.2c2-.63 4.02.2 5.1 1.86l1.7 2.6 1.7-2.6c1.08-1.66 3.1-2.49 5.1-1.86 3.18 1 4.3 4.7 2.53 7.56C18.7 16.65 12 21 12 21z" />
              </svg>
            </span>
          ))}
        </div>
      )}

      <motion.div
        initial={{ opacity: 0, scale: 0.94 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
        className="relative z-10"
      >
        <h1 className="font-serif text-4xl text-cream drop-shadow-sm sm:text-5xl">
          You said YES!&nbsp;&#9825;
        </h1>
        <p className="mt-1 font-serif text-2xl italic text-rose-bright sm:text-3xl">I&rsquo;m so excited!</p>

        <HeartDivider />

        <p className="text-sm uppercase tracking-[0.25em] text-cream/80">See you on</p>
        <p className="font-serif text-3xl text-cream sm:text-4xl">{PROM_DATE}</p>

        <motion.div
          initial={{ opacity: 0, y: 24, rotate: -6 }}
          animate={{ opacity: 1, y: 0, rotate: -3 }}
          transition={{ delay: 0.5, duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
          className="mx-auto mt-10 max-w-xs -rotate-3 rounded-sm bg-cream px-6 py-7 text-left shadow-[0_20px_50px_-16px_rgba(0,0,0,0.5)]"
        >
          <span className="block text-center text-rose">&#9825;</span>
          <p className="mt-2 font-serif text-base leading-relaxed text-ink/75">
            I would have loved to do this in person but hope it was as special as if we were in the
            same place.
          </p>
          <span className="mt-3 block text-center text-rose">&#9825;</span>
        </motion.div>
      </motion.div>
    </div>
  );
}
