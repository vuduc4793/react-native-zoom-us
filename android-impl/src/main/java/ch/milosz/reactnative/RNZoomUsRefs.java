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

    static synchronized String put(Object value) {
        String existing = BY_OBJECT.get(value);
        if (existing != null && BY_ID.containsKey(existing)) {
            BY_ID.get(existing); // refresh LRU order
            return existing;
        }
        String id = "a" + (++next);
        BY_ID.put(id, value);
        BY_OBJECT.put(value, id);
        // Keep the reverse map from outgrowing the forward one.
        if (BY_OBJECT.size() > MAX * 2) BY_OBJECT.keySet().retainAll(BY_ID.values());
        return id;
    }

    static synchronized Object get(String id) {
        return id == null ? null : BY_ID.get(id);
    }

    static synchronized void release(String id) {
        Object value = BY_ID.remove(id);
        if (value != null) BY_OBJECT.remove(value);
    }
}
