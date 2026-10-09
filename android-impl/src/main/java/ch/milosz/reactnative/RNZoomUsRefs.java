package ch.milosz.reactnative;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * SDK objects handed to JavaScript, by id.
 *
 * Every SDK object that crosses to JS -- a callback's handler, an info object,
 * a value a generic call returned -- is kept here and its payload carries
 * `__ref`. JS can then call any method on it (RNZoomUs.invokeRef), or pass it
 * back as an argument ({__ref}). That is how a prompt's handler is answered
 * from JS without a native release.
 *
 * Bounded: the oldest entries go first, so a ref JS holds on to for a very
 * long time can expire (invokeRef then rejects with ERR_ZOOM_REF_EXPIRED).
 *
 * Pinned entries are the exception: listeners JS created (the SDK holds them
 * weakly or must keep calling them) and prompt handlers waiting for an answer.
 * They live outside the LRU until releaseRef(id); a handler pinned "until
 * answered" is also unpinned by the first non-getter call JS makes on it.
 */
final class RNZoomUsRefs {
    private static final int MAX = 512;
    private static long next = 0;

    private static final Map<String, Object> BY_ID = new LinkedHashMap<String, Object>(64, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, Object> eldest) {
            return size() > MAX;
        }
    };
    /** Same object, same id -- identity, not equals(). */
    private static final Map<Object, String> BY_OBJECT = new java.util.IdentityHashMap<>();

    /** Strong, never evicted: id -> object. */
    private static final Map<String, Object> PINNED = new java.util.HashMap<>();
    /** Pinned ids that are released by their first non-getter call (handlers). */
    private static final java.util.Set<String> UNTIL_ANSWERED = new java.util.HashSet<>();

    static synchronized String put(Object value) {
        String existing = BY_OBJECT.get(value);
        if (existing != null && PINNED.containsKey(existing)) return existing;
        if (existing != null && BY_ID.containsKey(existing)) {
            BY_ID.get(existing); // refresh LRU order
            return existing;
        }
        String id = "a" + (++next);
        BY_ID.put(id, value);
        BY_OBJECT.put(value, id);
        // Keep the reverse map from outgrowing the forward one.
        if (BY_OBJECT.size() > MAX * 2) {
            java.util.Set<Object> live = java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<Object, Boolean>());
            live.addAll(BY_ID.values());
            live.addAll(PINNED.values());
            BY_OBJECT.keySet().retainAll(live);
        }
        return id;
    }

    /** Register and keep alive until release(id). */
    static synchronized String pin(Object value) {
        String id = put(value);
        PINNED.put(id, value);
        return id;
    }

    /** Register and keep alive until release(id) or the first call that answers it. */
    static synchronized String pinUntilAnswered(Object value) {
        String id = pin(value);
        UNTIL_ANSWERED.add(id);
        return id;
    }

    /**
     * JS called `method` on ref `id`. A handler pinned until answered drops
     * back to the LRU (so a late second call can still reach it for a while);
     * reading a getter first does not count as answering.
     */
    static synchronized void called(String id, String method) {
        if (id == null || !UNTIL_ANSWERED.contains(id)) return;
        if (method != null && ((method.startsWith("get") && method.length() > 3)
                || (method.startsWith("is") && method.length() > 2))) return;
        UNTIL_ANSWERED.remove(id);
        Object value = PINNED.remove(id);
        if (value != null && !BY_ID.containsKey(id)) BY_ID.put(id, value);
    }

    static synchronized Object get(String id) {
        if (id == null) return null;
        Object pinned = PINNED.get(id);
        return pinned != null ? pinned : BY_ID.get(id);
    }

    static synchronized void release(String id) {
        if (id == null) return;
        UNTIL_ANSWERED.remove(id);
        Object pinned = PINNED.remove(id);
        Object value = BY_ID.remove(id);
        if (value == null) value = pinned;
        if (value != null && id.equals(BY_OBJECT.get(value))) BY_OBJECT.remove(value);
    }
}
