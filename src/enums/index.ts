import { ZoomAndroidEnums } from "./android";
import { ZoomIosEnums } from "./ios";

export { ZoomAndroidEnums } from "./android";
export { ZoomIosEnums } from "./ios";

/**
 * Readable name for an enum value as an event delivered it, on either SDK.
 *
 *   zoomEnumName("MobileRTCMeetingState", payload.state)   // iOS number -> "MobileRTCMeetingState_InMeeting"
 *   zoomEnumName("InMeetingServiceListener_AudioStatus", 1) // Android ordinal -> "Audio_Muted"
 *
 * A string is returned unchanged (Android usually sends the name already).
 * Unknown enum or value -> undefined.
 */
export function zoomEnumName(enumName: string, value: number | string | null | undefined): string | undefined {
  if (typeof value === "string") return value;
  if (typeof value !== "number") return undefined;
  const ios = (ZoomIosEnums as Record<string, Record<string, number>>)[enumName];
  if (ios) {
    for (const [name, v] of Object.entries(ios)) if (v === value) return name;
    return undefined;
  }
  const android = (ZoomAndroidEnums as Record<string, readonly string[]>)[enumName];
  return android ? android[value] : undefined;
}
