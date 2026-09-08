"use client";

import { useRef, useState } from "react";
import { motion, useReducedMotion } from "motion/react";

const LABELS = ["I need a little\ntime to think", "…are you sure?", "take your time ♡"];
const TAPS_TO_REGISTER = 3;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/**
 * The soft-no button. Every *tap/click* on it makes it hop aside and shrink a
 * little; the 3rd tap gives up, wobbles, and registers the answer. It only
 * reacts to real taps (not hover), so it works the same on a phone — "just be
 * patient with the button" literally works.
 */
export default function EvasiveButton({ onRegister }: { onRegister: () => void }) {
  const reduce = useReducedMotion();
  const btnRef = useRef<HTMLButtonElement>(null);
  const firedRef = useRef(false);
  const lastTapRef = useRef(0);

  const [taps, setTaps] = useState(0);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [settled, setSettled] = useState(false);

  function register() {
    if (firedRef.current) return;
    firedRef.current = true;
    setSettled(true);
    setPos({ x: 0, y: 0 });
    window.setTimeout(onRegister, reduce ? 0 : 620);
  }

  function tap(pointerX?: number, pointerY?: number) {
    if (firedRef.current || settled) return;

    // pointerdown is immediately followed by a click — count the pair once
    const now = Date.now();
    if (now - lastTapRef.current < 400) return;
    lastTapRef.current = now;

    const next = taps + 1;
    setTaps(next);

    if (next >= TAPS_TO_REGISTER) {
      register();
      return;
    }
    if (reduce) return; // no hopping for reduced-motion, just count the taps

    // hop away from where she tapped, kept inside the button's row
    const btn = btnRef.current?.getBoundingClientRect();
    const box = btnRef.current?.parentElement?.getBoundingClientRect();
    const maxX = box && btn ? Math.max(36, box.width / 2 - btn.width / 2 - 6) : 90;
    const maxY = 78;

    let dx = Math.random() * 2 - 1;
    let dy = Math.random() * 2 - 1;
    if (btn && pointerX != null && pointerY != null) {
      dx = btn.left + btn.width / 2 - pointerX;
      dy = btn.top + btn.height / 2 - pointerY;
    }
    const len = Math.hypot(dx, dy) || 1;
    const dist = 84 + next * 14;
    setPos((p) => ({
      x: clamp(p.x + (dx / len) * dist + (Math.random() * 36 - 18), -maxX, maxX),
      y: clamp(p.y + (dy / len) * dist + (Math.random() * 22 - 11), -maxY, maxY),
    }));
  }

  const scale = settled ? 1 : Math.max(0.66, 1 - taps * 0.14);
  const label = LABELS[Math.min(taps, LABELS.length - 1)];

  return (
    <div className="relative grid min-h-[112px] w-full place-items-center sm:min-h-[68px]">
      <motion.button
        ref={btnRef}
        type="button"
        animate={
          settled && !reduce
            ? { x: 0, y: 0, scale: 1, rotate: [0, -4, 3, -2, 0] }
            : { x: pos.x, y: pos.y, scale }
        }
        transition={{ type: "spring", stiffness: 500, damping: 24, mass: 0.7 }}
        style={{ touchAction: "manipulation" }}
        onPointerDown={(e) => tap(e.clientX, e.clientY)}
        onClick={() => {
          if (settled) register();
          else if (Date.now() - lastTapRef.current >= 400) tap(); // keyboard activation
        }}
        className="w-full whitespace-pre-line rounded-xl border border-cream/25 bg-ink/45 px-6 py-3 text-center text-sm font-medium text-cream/90 backdrop-blur transition-colors hover:bg-ink/60"
      >
        {label}
      </motion.button>
    </div>
  );
}
