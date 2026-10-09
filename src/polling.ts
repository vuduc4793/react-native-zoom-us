import { zoom } from "./commands";
import { ZoomIosEnums } from "./enums";
import { bool, enumMember, isAndroid, listOf, num, onEvents, pick, str } from "./interaction-util";

/*
 * Polls and quizzes, one shape on both SDKs. Android:
 * InMeetingPollingController; iOS: MobileRTCMeetingService (+Polling).
 *
 * Answering: read the questions, tick answers with setChecked() / type with
 * setText() (each answer carries the SDK object as a ref), then submit().
 */

const z = zoom as any;
const ctl = () => (isAndroid ? z.InMeetingPollingController : z.MeetingService);
const IOS = ZoomIosEnums as unknown as Record<string, Record<string, number>>;

export type ZoomPollStatus = "Initial" | "Started" | "ShareResult" | "Stopped" | "";
export type ZoomPollQuestionKind =
  | "Single"
  | "Multi"
  | "Matching"
  | "RankOrder"
  | "ShortAnswer"
  | "LongAnswer"
  | "FillBlank"
  | "RatingScale"
  | "Dropdown"
  | "Unknown";

export interface ZoomPoll {
  id: string;
  name: string;
  status: ZoomPollStatus;
  /** "Poll" or "Quiz". */
  type: string;
  questionCount: number;
  votedCount: number;
  raw: any;
}

export interface ZoomPollAnswer {
  id: string;
  questionId: string;
  subQuestionId: string;
  name: string;
  checked: boolean;
  /** What was typed, for text questions. */
  text: string;
  /** Pass to setChecked()/setText(). */
  raw: any;
}

export interface ZoomPollQuestion {
  id: string;
  name: string;
  kind: ZoomPollQuestionKind;
  required: boolean;
  answeredCount: number;
  answers: ZoomPollAnswer[];
  /** Matching / rank order: one row per sub-question, each with its own answers. */
  subQuestions: ZoomPollQuestion[];
  raw: any;
}

export interface ZoomPollResult {
  questionId: string;
  subQuestionId: string;
  answerId: string;
  name: string;
  count: number;
}

async function safe<T>(call: () => Promise<T>, fallback: T): Promise<T> {
  try {
    const value = await call();
    return value ?? fallback;
  } catch {
    return fallback;
  }
}

export function toPoll(item: any): ZoomPoll | null {
  if (!item || typeof item !== "object") return null;
  const id = str(pick(item, "pollingID", "pollingId"));
  if (!id) return null;
  return {
    id,
    name: str(pick(item, "pollingName")),
    status: enumMember(pick(item, "pollingStatus"), IOS.MobileRTCPollingStatus ?? {}) as ZoomPollStatus,
    type: enumMember(pick(item, "pollingType"), IOS.MobileRTCPollingType ?? {}),
    questionCount: num(pick(item, "pollingQuestionCount")),
    votedCount: num(pick(item, "totalVotedUserCount")),
    raw: item,
  };
}

function toAnswer(item: any): ZoomPollAnswer | null {
  if (!item || typeof item !== "object") return null;
  return {
    id: str(pick(item, "pollingAnswerID", "pollingAnswerId")),
    questionId: str(pick(item, "pollingQuestionID", "pollingQuestionId")),
    subQuestionId: str(pick(item, "pollingSubQuestionID", "pollingSubQuestionId")),
    name: str(pick(item, "pollingAnswerName")),
    checked: bool(pick(item, "checked", "isChecked")),
    text: str(pick(item, "pollingAnsweredContent")),
    raw: item,
  };
}

async function toQuestion(item: any, depth = 0): Promise<ZoomPollQuestion | null> {
  if (!item || typeof item !== "object") return null;
  const [answers, subs] = await Promise.all([
    listOf(item, "getPollingAnswerItemList"),
    depth === 0 ? listOf(item, "getPollingSubQuestionItemList") : Promise.resolve([]),
  ]);
  const subQuestions = await Promise.all(subs.map((s) => toQuestion(s, depth + 1)));
  return {
    id: str(pick(item, "pollingQuestionID", "pollingQuestionId")),
    name: str(pick(item, "pollingQuestionName")),
    kind: (enumMember(pick(item, "pollingQuestionType"), IOS.MobileRTCPollingQuestionType ?? {}) || "Unknown") as ZoomPollQuestionKind,
    required: bool(pick(item, "required", "isRequired")),
    answeredCount: num(pick(item, "answeredCount")),
    answers: answers.map(toAnswer).filter((a): a is ZoomPollAnswer => a != null),
    subQuestions: subQuestions.filter((q): q is ZoomPollQuestion => q != null),
    raw: item,
  };
}

/** Whether this user can answer polls in this meeting. */
export async function canAnswer(): Promise<boolean> {
  return bool(await safe(() => ctl().canDoPolling(), false));
}

/** The poll currently open for answers, if any. */
export async function getActivePoll(): Promise<ZoomPoll | null> {
  const id = str(await safe(() => ctl().getActivePollingID(), ""));
  return id ? getPoll(id) : null;
}

export async function getPoll(pollId: string): Promise<ZoomPoll | null> {
  if (!pollId) return null;
  return toPoll(await safe(() => ctl().getPollingItemByID(pollId), null));
}

export async function getPolls(): Promise<ZoomPoll[]> {
  const list = await safe<any[]>(() => ctl().getPollingItemList(), []);
  return Array.isArray(list) ? list.map(toPoll).filter((p): p is ZoomPoll => p != null) : [];
}

export async function getQuestions(pollId: string): Promise<ZoomPollQuestion[]> {
  if (!pollId) return [];
  const list = await safe<any[]>(() => ctl().getPollingQuestionItemList(pollId), []);
  if (!Array.isArray(list)) return [];
  const questions = await Promise.all(list.map((q) => toQuestion(q)));
  return questions.filter((q): q is ZoomPollQuestion => q != null);
}

function answerRef(answer: ZoomPollAnswer | { raw?: any }): { __ref: string } | null {
  const r = answer?.raw?.__ref;
  return typeof r === "string" && r ? { __ref: r } : null;
}

/** Tick or untick a choice. Resolves whether the SDK accepted it. */
export async function setChecked(answer: ZoomPollAnswer, checked: boolean): Promise<boolean> {
  const r = answerRef(answer);
  if (!r) return false;
  const result = await safe(
    () => (isAndroid ? ctl().setAnswerCheck(r, !!checked) : ctl()["setAnswerCheck:check:"](r, !!checked)),
    null
  );
  return isSuccess(result);
}

/** The text for a short/long answer or fill-in-the-blank. */
export async function setText(answer: ZoomPollAnswer, text: string): Promise<boolean> {
  const r = answerRef(answer);
  if (!r) return false;
  const value = typeof text === "string" ? text : "";
  const result = await safe(
    () => (isAndroid ? ctl().setAnswerContent(r, value) : ctl()["setAnswerContent:answerText:"](r, value)),
    null
  );
  return isSuccess(result);
}

export async function canSubmit(pollId: string): Promise<boolean> {
  if (!pollId) return false;
  return bool(await safe(() => ctl().canSubmitPolling(pollId), false));
}

export async function submit(pollId: string): Promise<boolean> {
  if (!pollId) return false;
  return isSuccess(await safe(() => ctl().submitPolling(pollId), null));
}

/** Results the host shared (empty until they do). */
export async function getResults(pollId: string): Promise<ZoomPollResult[]> {
  if (!pollId) return [];
  if (!bool(await safe(() => ctl().canShowAnswerResultList(pollId), false))) return [];
  const list = await safe<any[]>(() => ctl().getPollingAnswerResultItemList(pollId), []);
  if (!Array.isArray(list)) return [];
  return list
    .filter((r) => r && typeof r === "object")
    .map((r) => ({
      questionId: str(pick(r, "pollingQuestionID", "pollingQuestionId")),
      subQuestionId: str(pick(r, "pollingSubQuestionID", "pollingSubQuestionId")),
      answerId: str(pick(r, "pollingAnswerID", "pollingAnswerId")),
      name: str(pick(r, "pollingAnswerName")),
      count: num(pick(r, "selectedCount")),
    }));
}

/** MobileRTCSDKError / Android MobileRTCSDKError: 0 or "SDKERR_SUCCESS". */
function isSuccess(result: unknown): boolean {
  return result === 0 || result === "SDKERR_SUCCESS" || result === "MobileRTCSDKError_Success";
}

/**
 * Call `callback` when polls change (opened, closed, results shared, list
 * updated). Re-read with getActivePoll()/getQuestions()/getResults().
 */
export function onChange(callback: () => void): () => void {
  return onEvents((event) => /^onPolling|RightAnswerList/.test(event), callback);
}
