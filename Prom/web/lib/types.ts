export type Answer = "yes" | "no";

export type ServerState = {
  unlocked: boolean;
  answered: Answer | null;
  answeredAt?: string;
};

export type AnswerResult = {
  answer: Answer;
  at: string;
  changed: boolean;
};

/** Which screen of the gesture we're on. */
export type Screen = "loading" | "gate" | "ask" | "yes" | "no";
