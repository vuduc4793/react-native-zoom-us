import { zoom } from "./commands";
import { bool, epochMs, isAndroid, listOf, num, onEvents, pick, str } from "./interaction-util";

/*
 * Webinar Q&A, one shape on both SDKs. Android: InMeetingQAController;
 * iOS: MobileRTCMeetingService (+QA category). Q&A exists only in webinars
 * where the host turned it on -- check isAvailable() first.
 */

const z = zoom as any;
const qa = () => (isAndroid ? z.InMeetingQAController : z.MeetingService);

export interface ZoomAnswer {
  id: string;
  text: string;
  senderName: string;
  time: number | null;
  isPrivate: boolean;
  isLive: boolean;
  isMine: boolean;
  raw: any;
}

export interface ZoomQuestion {
  id: string;
  text: string;
  /** Empty when asked anonymously. */
  senderName: string;
  time: number | null;
  isAnonymous: boolean;
  isAnswered: boolean;
  isDismissed: boolean;
  upvotes: number;
  upvotedByMe: boolean;
  isMine: boolean;
  /** Someone is answering it live right now. */
  liveAnswering: boolean;
  liveAnswerName: string;
  answers: ZoomAnswer[];
  raw: any;
}

export interface ZoomQAPermissions {
  /** Q&A is on for this webinar. */
  enabled: boolean;
  canAsk: boolean;
  canAskAnonymously: boolean;
  canSeeAllQuestions: boolean;
  canUpvote: boolean;
  canComment: boolean;
}

export type ZoomQuestionList = "all" | "my" | "open" | "answered" | "dismissed";

const LIST_GETTER: Record<ZoomQuestionList, string> = {
  all: "getAllQuestionList",
  my: "getMyQuestionList",
  open: "getOpenQuestionList",
  answered: "getAnsweredQuestionList",
  dismissed: "getDismissedQuestionList",
};

async function safe<T>(call: () => Promise<T>, fallback: T): Promise<T> {
  try {
    const value = await call();
    return value ?? fallback;
  } catch {
    return fallback;
  }
}

export function toAnswer(item: any): ZoomAnswer | null {
  if (!item || typeof item !== "object") return null;
  return {
    id: str(pick(item, "answerID", "answerId")),
    text: str(pick(item, "text")),
    senderName: str(pick(item, "senderName")),
    time: epochMs(pick(item, "timeStamp", "time")),
    isPrivate: bool(pick(item, "private", "isPrivate")),
    isLive: bool(pick(item, "liveAnswer", "isLiveAnswer")),
    isMine: bool(pick(item, "senderMyself", "isSenderMyself")),
    raw: item,
  };
}

/** One question; answers are filled by getQuestions(), not here. */
export function toQuestion(item: any): ZoomQuestion | null {
  if (!item || typeof item !== "object") return null;
  const id = str(pick(item, "questionID", "questionId"));
  if (!id) return null;
  return {
    id,
    text: str(pick(item, "text")),
    senderName: str(pick(item, "senderName")),
    time: epochMs(pick(item, "timeStamp", "time")),
    isAnonymous: bool(pick(item, "anonymous", "isAnonymous")),
    isAnswered: bool(pick(item, "markedAsAnswered", "isMarkedAsAnswered")),
    isDismissed: bool(pick(item, "markedAsDismissed", "isMarkedAsDismissed")),
    upvotes: num(pick(item, "upvoteNum", "upvoteNumber")),
    upvotedByMe: bool(pick(item, "mySelfUpvoted", "isMySelfUpvoted")),
    isMine: bool(pick(item, "senderMyself", "isSenderMyself")),
    liveAnswering: bool(pick(item, "liveAnswering", "isLiveAnswering")),
    liveAnswerName: str(pick(item, "liveAnswerName")),
    answers: [],
    raw: item,
  };
}

export async function isAvailable(): Promise<boolean> {
  return bool(await safe(() => qa().isQAEnabled(), false));
}

export async function getPermissions(): Promise<ZoomQAPermissions> {
  const c = qa();
  const [enabled, canAsk, anon, viewAll, upvote, comment] = await Promise.all(
    isAndroid
      ? [
          safe(() => c.isQAEnabled(), false),
          safe(() => c.isAskQuestionEnabled(), false),
          safe(() => c.isAskQuestionAnonymouslyEnabled(), false),
          safe(() => c.isAttendeeCanViewAllQuestions(), false),
          safe(() => c.isQAVoteupEnabled(), false),
          safe(() => c.isQACommentEnabled(), false),
        ]
      : [
          safe(() => c.isQAEnabled(), false),
          safe(() => c.isAskQuestionEnabled(), false),
          safe(() => c.isAllowAskQuestionAnonymously(), false),
          safe(() => c.isAllowAttendeeViewAllQuestion(), false),
          safe(() => c.isAllowAttendeeUpVoteQuestion(), false),
          safe(() => c.isAllowCommentQuestion(), false),
        ]
  );
  return {
    enabled: bool(enabled),
    canAsk: bool(canAsk),
    canAskAnonymously: bool(anon),
    canSeeAllQuestions: bool(viewAll),
    canUpvote: bool(upvote),
    canComment: bool(comment),
  };
}

/**
 * Questions with their answers, newest last. `list` "all" is what an
 * attendee may see (only their own when the host hides the others).
 */
export async function getQuestions(list: ZoomQuestionList = "all"): Promise<ZoomQuestion[]> {
  const items = await safe<any[]>(() => qa()[LIST_GETTER[list]](), []);
  if (!Array.isArray(items)) return [];
  const questions = await Promise.all(
    items.map(async (item) => {
      const q = toQuestion(item);
      if (!q) return null;
      // Nested lists only cross the bridge as refs; read them from the question.
      const answers = await listOf(item, isAndroid ? "getAnswerList" : "getAnswerlist");
      q.answers = answers.map(toAnswer).filter((a): a is ZoomAnswer => a != null);
      return q;
    })
  );
  return questions
    .filter((q): q is ZoomQuestion => q != null)
    .sort((a, b) => (a.time ?? 0) - (b.time ?? 0));
}

/** Ask the host/panelists. Resolves whether the SDK accepted it. */
export async function ask(text: string, anonymous = false): Promise<boolean> {
  const content = typeof text === "string" ? text.trim() : "";
  if (!content) return false;
  return bool(
    await safe(
      () => (isAndroid ? qa().addQuestion(content, !!anonymous) : qa()["addQuestion:anonymous:"](content, !!anonymous)),
      false
    )
  );
}

export async function upvote(questionId: string, up = true): Promise<boolean> {
  if (!questionId) return false;
  return bool(
    await safe(
      () => (isAndroid ? qa().voteupQuestion(questionId, !!up) : qa()["voteupQuestion:voteup:"](questionId, !!up)),
      false
    )
  );
}

export async function comment(questionId: string, text: string): Promise<boolean> {
  const content = typeof text === "string" ? text.trim() : "";
  if (!questionId || !content) return false;
  return bool(
    await safe(
      () =>
        isAndroid
          ? qa().commentQuestion(questionId, content)
          : qa()["commentQuestion:commentContent:"](questionId, content),
      false
    )
  );
}

const QA_EVENT = /QA|Question|Answer|Living/;

/**
 * Call `callback` when anything about Q&A changes (asked, answered, voted,
 * dismissed, permissions). Re-read with getQuestions()/getPermissions().
 * Returns the unsubscribe function.
 */
export function onChange(callback: () => void): () => void {
  return onEvents((event) => QA_EVENT.test(event) && !/Polling/.test(event), callback);
}
