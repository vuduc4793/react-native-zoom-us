import { Platform } from "react-native";
import { addZoomAnyListener } from "./events";
import { ref } from "./commands";

/* Shared by src/qa.ts and src/polling.ts. */

export const isAndroid = Platform.OS === "android";

/**
 * First present value among the spellings the two SDKs use for one getter:
 * Android drops "get"/"is" (isAnonymous -> anonymous), iOS drops only "get"
 * (isAnonymous stays isAnonymous) and sometimes cases differently (ID / Id).
 */
export function pick(obj: any, ...keys: string[]): any {
  if (!obj || typeof obj !== "object") return undefined;
  for (const k of keys) if (obj[k] !== undefined && obj[k] !== null) return obj[k];
  return undefined;
}

export function bool(value: unknown): boolean {
  return value === true || value === 1 || value === "true";
}

export function str(value: unknown): string {
  return typeof value === "string" ? value : value == null ? "" : String(value);
}

export function num(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

/** Seconds or ms, as either SDK gives them, to epoch ms (null when absent). */
export function epochMs(value: unknown): number | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n < 1e12 ? n * 1000 : n;
}

/** Enum value as its member name without the prefix: "SDKPollingStatus_Started" / 1 -> "Started". */
export function enumMember(value: unknown, iosTable: Record<string, number>): string {
  if (typeof value === "string") return value.slice(value.lastIndexOf("_") + 1);
  if (typeof value === "number") {
    for (const [name, v] of Object.entries(iosTable)) if (v === value) return name.slice(name.lastIndexOf("_") + 1);
  }
  return "";
}

/** A list getter on an object JS received (nested lists only arrive as refs). */
export async function listOf(owner: any, getter: string): Promise<any[]> {
  if (!owner?.__ref) return [];
  try {
    const list = await ref(owner)[getter]();
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

/**
 * Run `callback` (debounced) whenever an event whose name matches arrives.
 * The SDKs name the same callback differently (onAddQuestion /
 * onSinkQAAddQuestion), so matching is by pattern, and callers re-read state
 * instead of trusting each payload.
 */
export function onEvents(match: (event: string) => boolean, callback: () => void, delayMs = 150): () => void {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const subscription = addZoomAnyListener((payload: any) => {
    const event = payload?.event;
    if (typeof event !== "string" || !match(event)) return;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = undefined;
      try {
        callback();
      } catch (error) {
        console.warn("[react-native-zoom-us] listener threw", error);
      }
    }, delayMs);
  });
  return () => {
    if (timer) clearTimeout(timer);
    subscription.remove();
  };
}
