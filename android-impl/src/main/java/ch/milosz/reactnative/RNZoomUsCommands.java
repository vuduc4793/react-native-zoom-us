package ch.milosz.reactnative;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.lang.reflect.Array;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.Collection;
import java.util.List;
import java.util.Map;

import us.zoom.sdk.ZoomSDK;

/**
 * Calls any Zoom SDK method by name, so the bridge does not have to grow a
 * hand-written wrapper per call.
 *
 * The SDK exposes ~967 callable methods across 57 objects reachable from
 * ZoomSDK.getInstance(). Writing those out twice -- once per platform -- would
 * be thousands of lines that go stale on the next SDK bump, and anything left
 * out costs a native rebuild and a republish to add later. Reflection costs one
 * class instead, and a method added by a future SDK is reachable the moment
 * scripts/generate-commands.py is re-run, with no native change at all.
 *
 * Safe against R8 because android-impl/proguard.cfg keeps us.zoom.** with all
 * members, as a consumer rule, so names survive into the release build.
 *
 * JavaScript sends the route it wants rather than a nickname the native side
 * would have to keep a table for: "getInMeetingService.getInMeetingChatController"
 * walks ZoomSDK.getInstance().getInMeetingService().getInMeetingChatController().
 */
class RNZoomUsCommands {

  /** How deep to follow SDK objects when flattening a return value. */
  private static final int MAX_DEPTH = 2;

  static Object resolve(String path) throws Exception {
    Object target = ZoomSDK.getInstance();
    if (path == null || path.isEmpty()) return target;

    for (String step : path.split("\\.")) {
      if (step.isEmpty()) continue;
      Method getter = target.getClass().getMethod(step);
      getter.setAccessible(true);
      target = getter.invoke(target);
      if (target == null) {
        throw new IllegalStateException(
            step + "() returned null; the SDK is not in a state where "
                + path + " exists yet");
      }
    }
    return target;
  }

  static Object call(Object target, String name, ReadableArray args) throws Exception {
    int count = args == null ? 0 : args.size();

    // Overloads are matched on arity first, then on whether the arguments
    // actually coerce, so joinMeeting(long) and joinMeeting(String) both work
    // from a single JavaScript call.
    Exception lastFailure = null;
    for (Method method : target.getClass().getMethods()) {
      if (!method.getName().equals(name)) continue;
      if (method.getParameterTypes().length != count) continue;
      if (Modifier.isStatic(method.getModifiers())) continue;
      try {
        Object[] coerced = coerceAll(method.getParameterTypes(), args);
        method.setAccessible(true);
        return method.invoke(target, coerced);
      } catch (IllegalArgumentException ex) {
        lastFailure = ex;
      }
    }
    if (lastFailure != null) throw lastFailure;
    throw new NoSuchMethodException(
        target.getClass().getSimpleName() + "." + name + " taking " + count + " argument(s)");
  }

  private static Object[] coerceAll(Class<?>[] types, ReadableArray args) {
    Object[] out = new Object[types.length];
    for (int i = 0; i < types.length; i++) {
      out[i] = coerce(types[i], args, i);
    }
    return out;
  }

  @SuppressWarnings({"unchecked", "rawtypes"})
  private static Object coerce(Class<?> type, ReadableArray args, int i) {
    if (args.isNull(i)) {
      if (type.isPrimitive()) {
        throw new IllegalArgumentException("argument " + i + " is null but " + type + " is primitive");
      }
      return null;
    }

    if (type == boolean.class || type == Boolean.class) return args.getBoolean(i);
    if (type == int.class || type == Integer.class) return (int) args.getDouble(i);
    if (type == long.class || type == Long.class) return (long) args.getDouble(i);
    if (type == short.class || type == Short.class) return (short) args.getDouble(i);
    if (type == byte.class || type == Byte.class) return (byte) args.getDouble(i);
    if (type == float.class || type == Float.class) return (float) args.getDouble(i);
    if (type == double.class || type == Double.class) return args.getDouble(i);
    if (type == String.class || type == CharSequence.class) return args.getString(i);

    if (type.isEnum()) {
      // Accept either the constant's name or its ordinal, because that is what
      // the generated TypeScript says the value may be.
      if (args.getType(i) == ReadableType.Number) {
        Object[] constants = type.getEnumConstants();
        int ordinal = (int) args.getDouble(i);
        if (ordinal < 0 || ordinal >= constants.length) {
          throw new IllegalArgumentException("no constant " + ordinal + " in " + type.getSimpleName());
        }
        return constants[ordinal];
      }
      return Enum.valueOf((Class<Enum>) type, args.getString(i));
    }

    if (List.class.isAssignableFrom(type)) {
      ReadableArray nested = args.getArray(i);
      java.util.ArrayList<Object> list = new java.util.ArrayList<>();
      for (int n = 0; nested != null && n < nested.size(); n++) {
        switch (nested.getType(n)) {
          case Number: list.add((long) nested.getDouble(n)); break;
          case String: list.add(nested.getString(n)); break;
          case Boolean: list.add(nested.getBoolean(n)); break;
          default: throw new IllegalArgumentException("unsupported list element at " + n);
        }
      }
      return list;
    }

    if (type.isArray() && type.getComponentType() == long.class) {
      ReadableArray nested = args.getArray(i);
      int size = nested == null ? 0 : nested.size();
      long[] out = new long[size];
      for (int n = 0; n < size; n++) out[n] = (long) nested.getDouble(n);
      return out;
    }

    throw new IllegalArgumentException(
        "cannot convert argument " + i + " to " + type.getName()
            + "; this call needs a native wrapper rather than the generic bridge");
  }

  /** Turn an SDK return value into something the bridge can carry. */
  static Object marshal(Object value, int depth) {
    if (value == null) return null;
    if (value instanceof Boolean || value instanceof String) return value;
    if (value instanceof Number) return ((Number) value).doubleValue();
    if (value instanceof Enum) return ((Enum<?>) value).name();

    if (value instanceof Collection) {
      WritableArray out = Arguments.createArray();
      for (Object item : (Collection<?>) value) push(out, marshal(item, depth + 1));
      return out;
    }

    if (value.getClass().isArray()) {
      WritableArray out = Arguments.createArray();
      for (int i = 0; i < Array.getLength(value); i++) {
        push(out, marshal(Array.get(value, i), depth + 1));
      }
      return out;
    }

    if (value instanceof Map) {
      WritableMap out = Arguments.createMap();
      for (Map.Entry<?, ?> e : ((Map<?, ?>) value).entrySet()) {
        put(out, String.valueOf(e.getKey()), marshal(e.getValue(), depth + 1));
      }
      return out;
    }

    // An SDK object: flatten its no-argument getters, which is the only shape
    // that can cross the bridge. Depth-limited because some of them hold
    // references back into the meeting graph.
    if (depth >= MAX_DEPTH) return value.toString();
    WritableMap out = Arguments.createMap();
    for (Method method : value.getClass().getMethods()) {
      String name = method.getName();
      if (method.getParameterTypes().length != 0) continue;
      if (method.getDeclaringClass() == Object.class) continue;
      boolean getter = name.startsWith("get") && name.length() > 3;
      boolean predicate = name.startsWith("is") && name.length() > 2;
      if (!getter && !predicate) continue;
      String key = getter ? name.substring(3) : name.substring(2);
      key = Character.toLowerCase(key.charAt(0)) + key.substring(1);
      try {
        method.setAccessible(true);
        put(out, key, marshal(method.invoke(value), depth + 1));
      } catch (Throwable ignored) {
        // A getter that throws outside a meeting is normal; leave the key out.
      }
    }
    return out;
  }

  private static void push(WritableArray array, Object value) {
    if (value == null) array.pushNull();
    else if (value instanceof Boolean) array.pushBoolean((Boolean) value);
    else if (value instanceof Double) array.pushDouble((Double) value);
    else if (value instanceof String) array.pushString((String) value);
    else if (value instanceof WritableArray) array.pushArray((WritableArray) value);
    else if (value instanceof WritableMap) array.pushMap((WritableMap) value);
    else array.pushString(String.valueOf(value));
  }

  private static void put(WritableMap map, String key, Object value) {
    if (value == null) map.putNull(key);
    else if (value instanceof Boolean) map.putBoolean(key, (Boolean) value);
    else if (value instanceof Double) map.putDouble(key, (Double) value);
    else if (value instanceof String) map.putString(key, (String) value);
    else if (value instanceof WritableArray) map.putArray(key, (WritableArray) value);
    else if (value instanceof WritableMap) map.putMap(key, (WritableMap) value);
    else map.putString(key, String.valueOf(value));
  }
}
