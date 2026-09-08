"use client";

import { useEffect, useRef, useState } from "react";
import { motion } from "motion/react";
import HeartDivider from "./HeartDivider";

/**
 * Drop any track at /public/audio/sad.mp3 and it plays here. NCS releases are
 * free to use *with attribution* — if you use one, credit it (see README).
 * No file → this silently does nothing.
 */
export default function NoResult({ onReconsider }: { onReconsider: () => void }) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [needsTap, setNeedsTap] = useState(false);

  useEffect(() => {
    const a = audioRef.current;
    if (!a) return;
    a.volume = 0.55;
    a.play().catch(() => setNeedsTap(true));
  }, []);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 1.1 }}
      className="relative w-full max-w-md text-center"
    >
      <audio ref={audioRef} src="/audio/sad.mp3" preload="auto" />

      <h1 className="font-serif text-4xl text-cream/90 sm:text-5xl">That&rsquo;s okay…</h1>
      <p className="mt-1 font-serif text-xl italic text-rose/90 sm:text-2xl">I respect your decision.</p>

      <HeartDivider variant="plain" />

      {needsTap && (
        <button
          type="button"
          onClick={() => {
            audioRef.current?.play().catch(() => {});
            setNeedsTap(false);
          }}
          className="mt-2 text-xs text-cream/40 underline underline-offset-4"
        >
          play music
        </button>
      )}

      <button
        type="button"
        onClick={onReconsider}
        className="mt-10 block w-full text-xs text-cream/35 transition hover:text-cream/60"
      >
        …wait, I changed my mind&nbsp;&#9825;
      </button>

      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="pointer-events-none fixed bottom-8 right-8 h-12 w-12 text-cream/15"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        strokeLinejoin="round"
      >
        <path d="M12 20s-7-4.5-9.5-9C1 8 2.5 4.5 6 4c2-.3 3.7 1 4.5 2.3L9 9l3 2-2 3 2 6z" />
        <path d="M12 6.3C12.8 5 14.5 3.7 16.5 4 20 4.5 21.5 8 20.5 11 19 14 14 18 12 20" />
      </svg>
    </motion.div>
  );
}
