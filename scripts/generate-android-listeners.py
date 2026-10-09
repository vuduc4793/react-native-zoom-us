#!/usr/bin/env python3
"""Generate RNZoomUsListeners.java: every notification-only Zoom Android
listener the module does not register by hand, forwarded to JS.

Inputs
  - an SDK inventory JSON (listeners with registeredVia + callbacks), produced
    from `javap -public` of mobilertc's classes.jar; pass its path as argv[1]
  - src/commands/android-api.json for the getter path to each owner object
  - src/events/ios-events.json, so a callback iOS also has gets the same
    payload keys on Android
  - RNZoomUsModule.java, to skip callbacks the module already emits

The Java side uses java.lang.reflect.Proxy, so a callback the SDK adds to one
of these interfaces later is forwarded without regenerating; regenerate to pick
up new *interfaces* or to change which are attached.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULE = ROOT / "android-impl/src/main/java/ch/milosz/reactnative/RNZoomUsModule.java"
OUT = ROOT / "android-impl/src/main/java/ch/milosz/reactnative/RNZoomUsListeners.java"

# Not attached here, and why:
#  - registered by RNZoomUsModule itself
ALREADY = {
    "InMeetingServiceListener", "MeetingServiceListener", "ZoomSDKInitializeListener",
    "InMeetingShareController$InMeetingShareListener", "InMeetingBOControllerListener",
    "IBOAttendeeEvent", "IBOAdminEvent",
}
#  - change Zoom's behaviour or own a prompt: phase 2, with a JS responder
BEHAVIOUR = {
    "ZoomUIDelegate", "NetworkConnectionListener", "IReminderHelper$IReminderEvent",
    "InMeetingNotificationHandle", "ICustomShareOptionItem",
    "MeetingInviteMenuItem$MeetingInviteAction",
}
#  - raw media pipelines: callbacks per frame, not events
RAW = {
    "ICustomizedVideoSink", "IZoomSDKAudioRawDataDelegate", "IZoomSDKVideoRawDataDelegate",
    "IZoomSDKVirtualAudioMicEvent", "ZoomSDKPreProcessor", "ZoomSDKShareAudioSource",
    "ZoomSDKShareSource", "ZoomSDKVideoSource",
}
# Owners the generic-bridge route table does not list.
EXTRA_PATHS = {
    "ZoomSDK": [],
    "InMeetingIndicatorController": ["getInMeetingService", "getInMeetingIndicatorController"],
    "ZoomSDKAICompanionSmartSummaryHelper": [
        "getInMeetingService", "getInMeetingAICompanionController", "getSmartSummaryHelper"],
}


def main():
    inventory = json.loads(Path(sys.argv[1]).read_text())
    api = json.loads((ROOT / "src/commands/android-api.json").read_text())
    ios = json.loads((ROOT / "src/events/ios-events.json").read_text())
    module = MODULE.read_text()
    emitted = set(re.findall(r'emitZoomEvent\("(\w+)"', module))
    emitted |= set(re.findall(r'send(?:Event|Both|EventChatInfo)\("\w+", "(\w+)"', module))

    # Callbacks iOS names differently (src/events/event-aliases.json): take the keys
    # from the iOS name, so the payload matches under both names.
    renamed = {a: i for a, i in json.loads((ROOT / "src/events/event-aliases.json").read_text())["rename"]}

    paths = {name: info["path"] for name, info in api.items()}
    paths.update(EXTRA_PATHS)

    specs, names, skipped_owner = [], {}, []
    for listener in inventory["listeners"]:
        if listener["role"] != "registrable-callback":
            continue
        short = listener["name"].split(".")[-1]
        if short in ALREADY | BEHAVIOUR | RAW:
            continue
        owner, method = listener["registeredVia"][0].split(".")
        if owner not in paths:
            skipped_owner.append(short)
            continue
        specs.append((listener["name"], paths[owner], method))
        for cb in listener["callbacks"]:
            keys = [k for k, _ in ios.get(cb["name"], ios.get(renamed.get(cb["name"], ""), []))]
            # iOS now sends both `foo` (serialized) and `fooPresent` (legacy flag)
            # for one parameter; count the parameter once.
            keys = [k for k in keys if not (k.endswith("Present") and k[:-len("Present")] in keys)]
            # iOS names: only when the arity lines up. A `xxxPresent` key is how
            # iOS reports an object it cannot serialize; here the object itself
            # is serialized, under the name without the suffix.
            if keys and len(keys) == len(cb["params"]):
                names[cb["name"]] = [k[:-len("Present")] if k.endswith("Present") else k for k in keys]

    def jstr(s):
        return '"' + s + '"'

    spec_lines = ",\n".join(
        f"        new Spec({jstr(iface)}, new String[]{{{', '.join(jstr(p) for p in path)}}}, {jstr(method)})"
        for iface, path, method in specs)
    name_lines = "\n".join(
        f"        NAMES.put({jstr(cb)}, new String[]{{{', '.join(jstr(k) for k in keys)}}});"
        for cb, keys in sorted(names.items()))
    skip_lines = "\n".join(f"        ALREADY_EMITTED.add({jstr(e)});" for e in sorted(emitted))

    # Event list for scripts/generate-events.py: every forwarded callback with
    # its named keys (if any). `args` is always present.
    manifest = {}
    for listener in inventory["listeners"]:
        if listener["name"] not in {iface for iface, _, _ in specs}:
            continue
        for cb in listener["callbacks"]:
            if cb["name"] in emitted:
                continue
            manifest[cb["name"]] = names.get(cb["name"], [])
    (ROOT / "src/events/android-listener-events.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")

    java = TEMPLATE.replace("%SPECS%", spec_lines).replace("%NAMES%", name_lines).replace("%SKIP%", skip_lines)
    OUT.write_text(java)
    print(f"wrote {OUT.name}: {len(specs)} listener interfaces, {len(names)} callbacks named after iOS, "
          f"{len(emitted)} module-emitted names skipped; owner unreachable: {skipped_owner}")


TEMPLATE = '''// AUTO-GENERATED by scripts/generate-android-listeners.py. Do not edit by hand.
package ch.milosz.reactnative;

import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Proxy;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;

import us.zoom.sdk.ZoomSDK;

/**
 * Forwards every callback of the notification-only Zoom listeners that
 * RNZoomUsModule does not register itself. One reflective proxy per interface:
 * nothing here can change what Zoom does -- every callback returns the
 * interface's default (false / 0 / null), i.e. "not handled".
 *
 * Payload: named keys where the same callback exists on iOS (same names as
 * iOS sends), plus `args` -- every argument in order -- for all of them.
 * SDK objects are serialized from their public getters, two levels deep.
 */
final class RNZoomUsListeners {
    private static final String TAG = "RNZoomUsListeners";

    interface Emitter {
        void emit(String event, WritableMap payload);
    }

    private static final class Spec {
        final String iface;
        final String[] path;
        final String registrar;

        Spec(String iface, String[] path, String registrar) {
            this.iface = iface;
            this.path = path;
            this.registrar = registrar;
        }
    }

    private static final Spec[] SPECS = {
%SPECS%
    };

    private static final Map<String, String[]> NAMES = new HashMap<>();
    private static final Set<String> ALREADY_EMITTED = new HashSet<>();

    static {
%NAMES%
%SKIP%
    }

    /** owner object -> interfaces already attached to it (owners are recreated per meeting). */
    private final Map<Object, Set<String>> attached = new WeakHashMap<>();
    private final Emitter emitter;

    RNZoomUsListeners(Emitter emitter) {
        this.emitter = emitter;
    }

    /**
     * Attach every listener whose owner exists right now. Safe to call often:
     * owners that are null are retried next time, and an owner already
     * attached is skipped. Call it whenever new owners may have appeared
     * (SDK ready, meeting status change, breakout-room rights granted).
     */
    synchronized void attachAll() {
        ZoomSDK sdk;
        try {
            sdk = ZoomSDK.getInstance();
            if (sdk == null || !sdk.isInitialized()) return;
        } catch (Throwable t) {
            return;
        }
        for (Spec spec : SPECS) {
            try {
                attach(sdk, spec);
            } catch (Throwable t) {
                Log.w(TAG, "attach " + spec.iface + " failed: " + t);
            }
        }
    }

    private void attach(ZoomSDK sdk, Spec spec) throws Exception {
        Object owner = sdk;
        for (String getter : spec.path) {
            Method m = owner.getClass().getMethod(getter);
            owner = m.invoke(owner);
            if (owner == null) return;
        }
        Set<String> done = attached.get(owner);
        if (done != null && done.contains(spec.iface)) return;

        Class<?> iface = Class.forName(spec.iface);
        Method register = null;
        for (Method m : owner.getClass().getMethods()) {
            if (m.getName().equals(spec.registrar) && m.getParameterTypes().length == 1
                    && m.getParameterTypes()[0].isAssignableFrom(iface)) {
                register = m;
                break;
            }
        }
        if (register == null) return;

        Object proxy = Proxy.newProxyInstance(iface.getClassLoader(), new Class<?>[]{iface}, new Forwarder());
        register.invoke(owner, proxy);
        if (done == null) {
            done = new HashSet<>();
            attached.put(owner, done);
        }
        done.add(spec.iface);
        Log.i(TAG, "attached " + iface.getSimpleName() + " to " + owner.getClass().getSimpleName());
    }

    private final class Forwarder implements InvocationHandler {
        @Override
        public Object invoke(Object proxy, Method method, Object[] args) {
            if (method.getDeclaringClass() == Object.class) {
                switch (method.getName()) {
                    case "equals": return proxy == args[0];
                    case "hashCode": return System.identityHashCode(proxy);
                    default: return "RNZoomUsListeners$Forwarder";
                }
            }
            String name = method.getName();
            if (!ALREADY_EMITTED.contains(name)) {
                try {
                    Log.d(TAG, "forward " + name);
                    emitter.emit(name, payload(name, args));
                } catch (Throwable t) {
                    Log.w(TAG, "emit " + name + " failed: " + t);
                }
            }
            return defaultValue(method.getReturnType());
        }
    }

    private static WritableMap payload(String name, Object[] args) {
        WritableMap map = Arguments.createMap();
        WritableArray all = Arguments.createArray();
        String[] keys = NAMES.get(name);
        int n = args == null ? 0 : args.length;
        for (int i = 0; i < n; i++) {
            pushTo(all, args[i], 0);
            if (keys != null && i < keys.length) putTo(map, keys[i], args[i], 0);
        }
        map.putArray("args", all);
        return map;
    }

    private static Object defaultValue(Class<?> type) {
        if (type == boolean.class) return false;
        if (type == int.class) return 0;
        if (type == long.class) return 0L;
        if (type == float.class) return 0f;
        if (type == double.class) return 0d;
        if (type == short.class) return (short) 0;
        if (type == byte.class) return (byte) 0;
        if (type == char.class) return (char) 0;
        return null;
    }

    private static final int MAX_DEPTH = 2;

    static void putTo(WritableMap map, String key, Object value, int depth) {
        if (value == null) map.putNull(key);
        else if (value instanceof Boolean) map.putBoolean(key, (Boolean) value);
        else if (value instanceof Number) map.putDouble(key, ((Number) value).doubleValue());
        else if (value instanceof CharSequence) map.putString(key, value.toString());
        else if (value instanceof Enum) map.putString(key, ((Enum<?>) value).name());
        else if (value instanceof Collection || value.getClass().isArray()) map.putArray(key, toArray(value, depth));
        else if (value instanceof Map) map.putMap(key, mapOf((Map<?, ?>) value, depth));
        else map.putMap(key, objectOf(value, depth));
    }

    static void pushTo(WritableArray array, Object value, int depth) {
        if (value == null) array.pushNull();
        else if (value instanceof Boolean) array.pushBoolean((Boolean) value);
        else if (value instanceof Number) array.pushDouble(((Number) value).doubleValue());
        else if (value instanceof CharSequence) array.pushString(value.toString());
        else if (value instanceof Enum) array.pushString(((Enum<?>) value).name());
        else if (value instanceof Collection || value.getClass().isArray()) array.pushArray(toArray(value, depth));
        else if (value instanceof Map) array.pushMap(mapOf((Map<?, ?>) value, depth));
        else array.pushMap(objectOf(value, depth));
    }

    private static WritableArray toArray(Object value, int depth) {
        WritableArray out = Arguments.createArray();
        if (value instanceof Collection) {
            for (Object item : (Collection<?>) value) pushTo(out, item, depth + 1);
        } else {
            int len = java.lang.reflect.Array.getLength(value);
            for (int i = 0; i < len; i++) pushTo(out, java.lang.reflect.Array.get(value, i), depth + 1);
        }
        return out;
    }

    private static WritableMap mapOf(Map<?, ?> value, int depth) {
        WritableMap out = Arguments.createMap();
        for (Map.Entry<?, ?> e : value.entrySet()) {
            putTo(out, String.valueOf(e.getKey()), e.getValue(), depth + 1);
        }
        return out;
    }

    /**
     * An SDK object as a map of its zero-argument public getters (getX/isX),
     * read through its public interfaces so obfuscated implementation classes
     * are never touched. Handlers and other objects JS cannot act on yet come
     * through with whatever state they expose, plus `__type`.
     * Package-private: RNZoomUsObjects serializes created objects and
     * prompt handlers with it too.
     */
    static WritableMap objectOf(Object value, int depth) {
        WritableMap out = Arguments.createMap();
        out.putString("__type", publicTypeName(value.getClass()));
        // Handlers and other SDK objects can be acted on from JS by this id.
        out.putString("__ref", RNZoomUsRefs.put(value));
        if (depth >= MAX_DEPTH) return out;
        for (Method m : publicGetters(value.getClass())) {
            String n = m.getName();
            String key = n.startsWith("is") ? n : Character.toLowerCase(n.charAt(3)) + n.substring(4);
            try {
                putTo(out, key, m.invoke(value), depth + 1);
            } catch (Throwable ignored) {
                // A getter that throws is left out rather than failing the event.
            }
        }
        return out;
    }

    private static String publicTypeName(Class<?> cls) {
        for (Class<?> c = cls; c != null; c = c.getSuperclass()) {
            if (Modifier.isPublic(c.getModifiers()) && c.getName().startsWith("us.zoom.sdk.")) return c.getSimpleName();
            for (Class<?> i : c.getInterfaces()) {
                if (i.getName().startsWith("us.zoom.sdk.")) return i.getSimpleName();
            }
        }
        return cls.getSimpleName();
    }

    private static Collection<Method> publicGetters(Class<?> cls) {
        Map<String, Method> found = new HashMap<>();
        Set<Class<?>> types = new HashSet<>();
        for (Class<?> c = cls; c != null; c = c.getSuperclass()) {
            if (c.getName().startsWith("us.zoom.sdk.") && Modifier.isPublic(c.getModifiers())) types.add(c);
            collectInterfaces(c, types);
        }
        for (Class<?> t : types) {
            for (Method m : t.getMethods()) {
                String n = m.getName();
                boolean getter = (n.startsWith("get") && n.length() > 3) || (n.startsWith("is") && n.length() > 2);
                if (!getter || m.getParameterTypes().length != 0 || m.getReturnType() == void.class) continue;
                if (n.equals("getClass") || Modifier.isStatic(m.getModifiers())) continue;
                found.put(n, m);
            }
        }
        return found.values();
    }

    private static void collectInterfaces(Class<?> c, Set<Class<?>> out) {
        for (Class<?> i : c.getInterfaces()) {
            if (i.getName().startsWith("us.zoom.sdk.")) out.add(i);
            collectInterfaces(i, out);
        }
    }
}
'''

if __name__ == "__main__":
    main()
