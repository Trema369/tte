"use client";

import { useState } from "react";
import { motion } from "motion/react";
import HeartDivider from "./HeartDivider";
import EvasiveButton from "./EvasiveButton";

type Props = {
  onYes: () => void;
  onNo: () => void;
};

const stagger = {
  hidden: {},
  show: { transition: { staggerChildren: 0.18, delayChildren: 0.1 } },
};
const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: [0.22, 1, 0.36, 1] as const } },
};

export default function Ask({ onYes, onNo }: Props) {
  const [busy, setBusy] = useState(false);

  function yes() {
    if (busy) return;
    setBusy(true);
    onYes();
  }

  return (
    <motion.div
      variants={stagger}
      initial="hidden"
      animate="show"
      className="w-full max-w-lg text-center"
    >
      <motion.h1 variants={item} className="font-serif text-5xl text-cream sm:text-6xl">
        Harley,
      </motion.h1>

      <motion.div variants={item}>
        <HeartDivider />
      </motion.div>

      <motion.p variants={item} className="text-lg text-cream/90 sm:text-xl">
        I just wanted to ask you
        <br />
        <span className="font-serif text-2xl italic text-rose sm:text-3xl">a special question.</span>
      </motion.p>

      <motion.p variants={item} className="mx-auto mt-5 max-w-xs text-xs leading-relaxed text-cream/60 sm:text-sm">
        When you&rsquo;re ready, take your time and answer whenever you&rsquo;ve decided.
      </motion.p>

      <motion.div variants={item}>
        <HeartDivider variant="plain" />
      </motion.div>

      <motion.h2 variants={item} className="font-serif text-3xl leading-snug text-cream sm:text-4xl">
        Will you be my
        <br />
        date to <span className="accent text-4xl sm:text-5xl">prom?</span>
      </motion.h2>

      <motion.div variants={item}>
        <HeartDivider />
      </motion.div>

      <motion.div
        variants={item}
        className="mt-2 flex flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:justify-center"
      >
        <button
          type="button"
          onClick={yes}
          disabled={busy}
          className="rounded-xl bg-crimson px-8 py-3.5 text-sm font-semibold text-cream shadow-glow transition hover:bg-crimson-deep disabled:opacity-60 sm:min-w-[190px]"
        >
          Yes, of course&nbsp;&#9825;
        </button>

        <div className="sm:min-w-[190px]">
          <EvasiveButton onRegister={onNo} />
        </div>
      </motion.div>

      <motion.p variants={item} className="mx-auto mt-4 max-w-sm text-[11px] leading-relaxed text-cream/45">
        If you want to say no, just be patient with the button and think about your decision&nbsp;&#9825;
      </motion.p>
    </motion.div>
  );
}
