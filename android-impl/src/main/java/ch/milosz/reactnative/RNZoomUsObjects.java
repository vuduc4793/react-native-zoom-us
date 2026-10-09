package ch.milosz.reactnative;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import us.zoom.sdk.IMeetingInviteMenuItem;
import us.zoom.sdk.IReminderHelper;
import us.zoom.sdk.NetworkConnectionListener;
import us.zoom.sdk.ProxySettingHandler;
import us.zoom.sdk.SSLCertVerificationHandler;
import us.zoom.sdk.VideoScene;
import us.zoom.sdk.ZoomSDK;
import us.zoom.sdk.ZoomUIDelegate;
import us.zoom.sdk.ZoomUIService;

/**
 * The parts of the bridge that let JS build and answer SDK objects without a
 * native release:
 *
 *  - create(className, props): any SDK value class (options, params...), its
 *    props applied through setters or public fields.
 *  - createListener(interfaceName): any SDK listener interface, every callback
 *    forwarded to JS as "onListenerCallback".
 *  - button overrides: Zoom's own meeting toolbar buttons, through ZoomUIDelegate.
 *  - opt-in prompts: the reminder (recording / AI disclaimers) and the network
 *    (proxy / SSL certificate) prompts, answered from JS through their handler.
 *
 * Nothing here may throw into the SDK or the bridge: every SDK and reflection
 * call is wrapped, because native code cannot be fixed over the air.
 */
final class RNZoomUsObjects {
    private static final String TAG = "RNZoomUsObjects";

    private final RNZoomUsListeners.Emitter emitter;

    RNZoomUsObjects(RNZoomUsListeners.Emitter emitter) {
        this.emitter = emitter;
    }

    private void emit(String event, WritableMap payload) {
        try {
            emitter.emit(event, payload);
        } catch (Throwable t) {
            Log.w(TAG, "emit " + event + " failed: " + t);
        }
    }

    // ---------------------------------------------------------------- classes

    /**
     * "JoinMeetingOptions" -> us.zoom.sdk.JoinMeetingOptions; a dotted name is
     * taken as given, and if that fails its trailing dots are tried as nested
     * class separators ("us.zoom.sdk.IReminderHelper.IReminderEvent").
     */
    static Class<?> classFor(String name) throws ClassNotFoundException {
        if (name == null || name.trim().isEmpty()) throw new ClassNotFoundException("empty class name");
        name = name.trim();
        ClassLoader loader = ZoomSDK.class.getClassLoader();
        String candidate = name.indexOf('.') < 0 ? "us.zoom.sdk." + name : name;
        ClassNotFoundException first = null;
        while (true) {
            try {
                return Class.forName(candidate, false, loader);
            } catch (ClassNotFoundException ex) {
                if (first == null) first = ex;
            }
            int dot = candidate.lastIndexOf('.');
            int pkgEnd = candidate.startsWith("us.zoom.sdk.") ? "us.zoom.sdk".length() : -1;
            if (dot <= pkgEnd || dot < 0) throw first;
            candidate = candidate.substring(0, dot) + "$" + candidate.substring(dot + 1);
        }
    }

    // ----------------------------------------------------------------- create

    /** Thrown with a message JS sees as-is (ERR_ZOOM_CREATE). */
    static final class CreateException extends Exception {
        private static final long serialVersionUID = 1L;

        CreateException(String message) {
            super(message);
        }
    }

    /** Instantiate, apply props, register; the serialized object (with __ref, __type). */
    WritableMap create(String className, ReadableMap props) throws Exception {
        Class<?> cls;
        try {
            cls = classFor(className);
        } catch (ClassNotFoundException ex) {
            throw new CreateException("unknown class " + className);
        }
        if (cls.isInterface() || Modifier.isAbstract(cls.getModifiers())) {
            throw new CreateException(cls.getName() + " is an interface or abstract; use createListener for interfaces");
        }
        Object instance;
        try {
            java.lang.reflect.Constructor<?> ctor = cls.getConstructor();
            instance = ctor.newInstance();
        } catch (NoSuchMethodException ex) {
            throw new CreateException(cls.getName() + " has no public no-argument constructor");
        } catch (java.lang.reflect.InvocationTargetException ex) {
            Throwable cause = ex.getCause() == null ? ex : ex.getCause();
            throw new CreateException(cls.getName() + "(): " + cause);
        }

        List<String> failed = new ArrayList<>();
        HashMap<String, Object> values = props == null ? new HashMap<String, Object>() : props.toHashMap();
        for (Map.Entry<String, Object> e : values.entrySet()) {
            String problem = applyProp(instance, e.getKey(), e.getValue());
            if (problem != null) failed.add(e.getKey() + " (" + problem + ")");
        }
        if (!failed.isEmpty()) {
            throw new CreateException("cannot set on " + cls.getSimpleName() + ": " + join(failed));
        }
        return RNZoomUsListeners.objectOf(instance, 0);
    }

    /** null on success, else why the prop could not be set. */
    private static String applyProp(Object instance, String key, Object value) {
        if (key == null || key.isEmpty()) return "empty name";
        String setter = "set" + Character.toUpperCase(key.charAt(0)) + key.substring(1);
        String lastProblem = null;
        for (Method m : instance.getClass().getMethods()) {
            if (!m.getName().equals(setter) || m.getParameterTypes().length != 1) continue;
            if (Modifier.isStatic(m.getModifiers())) continue;
            Object coerced;
            try {
                coerced = RNZoomUsCommands.coerceValue(m.getParameterTypes()[0], value);
            } catch (Throwable t) {
                lastProblem = "no " + setter + " overload takes this value: " + t.getMessage();
                continue;
            }
            try {
                m.setAccessible(true);
                m.invoke(instance, coerced);
                return null;
            } catch (java.lang.reflect.InvocationTargetException ex) {
                Throwable cause = ex.getCause() == null ? ex : ex.getCause();
                return setter + " threw " + cause;
            } catch (Throwable t) {
                lastProblem = setter + ": " + t;
            }
        }
        try {
            Field f = instance.getClass().getField(key);
            int mod = f.getModifiers();
            if (Modifier.isStatic(mod) || Modifier.isFinal(mod)) return "field " + key + " is static or final";
            f.set(instance, RNZoomUsCommands.coerceValue(f.getType(), value));
            return null;
        } catch (NoSuchFieldException ex) {
            return lastProblem != null ? lastProblem : "no " + setter + "(x) and no public field " + key;
        } catch (Throwable t) {
            return "field " + key + ": " + (t.getMessage() == null ? t.toString() : t.getMessage());
        }
    }

    private static String join(List<String> parts) {
        StringBuilder sb = new StringBuilder();
        for (String p : parts) {
            if (sb.length() > 0) sb.append(", ");
            sb.append(p);
        }
        return sb.toString();
    }

    // --------------------------------------------------------- createListener

    /** A pinned proxy for `interfaceName`; {__ref, __type}. */
    WritableMap createListener(String interfaceName) throws Exception {
        Class<?> iface;
        try {
            iface = classFor(interfaceName);
        } catch (ClassNotFoundException ex) {
            throw new CreateException("unknown interface " + interfaceName);
        }
        if (!iface.isInterface()) throw new CreateException(iface.getName() + " is not an interface");
        ListenerForwarder forwarder = new ListenerForwarder(iface.getSimpleName());
        Object proxy = Proxy.newProxyInstance(iface.getClassLoader(), new Class<?>[]{iface}, forwarder);
        forwarder.id = RNZoomUsRefs.pin(proxy);
        WritableMap out = Arguments.createMap();
        out.putString("__ref", forwarder.id);
        out.putString("__type", iface.getSimpleName());
        return out;
    }

    private final class ListenerForwarder implements InvocationHandler {
        final String type;
        volatile String id;

        ListenerForwarder(String type) {
            this.type = type;
        }

        @Override
        public Object invoke(Object proxy, Method method, Object[] args) {
            if (method.getDeclaringClass() == Object.class) {
                switch (method.getName()) {
                    case "equals": return args != null && args.length == 1 && proxy == args[0];
                    case "hashCode": return System.identityHashCode(proxy);
                    default: return "RNZoomUsListener(" + type + ", " + id + ")";
                }
            }
            try {
                WritableMap payload = Arguments.createMap();
                payload.putString("listener", id);
                payload.putString("method", method.getName());
                WritableArray all = Arguments.createArray();
                int n = args == null ? 0 : args.length;
                for (int i = 0; i < n; i++) {
                    try {
                        RNZoomUsListeners.pushTo(all, args[i], 0);
                    } catch (Throwable t) {
                        all.pushNull();
                    }
                }
                payload.putArray("args", all);
                emit("onListenerCallback", payload);
            } catch (Throwable t) {
                Log.w(TAG, "listener " + type + "." + method.getName() + " failed: " + t);
            }
            return defaultValue(method.getReturnType());
        }
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

    // ------------------------------------------------------- button overrides

    static final String[] BUTTONS = {"invite", "end", "audio", "video", "share", "more", "participants"};
    private final Map<String, Boolean> overrides = new HashMap<>();

    /** Replace the overrides: keys left out (or not booleans) go back to false. */
    synchronized void setButtonOverrides(ReadableMap map) {
        overrides.clear();
        if (map == null) return;
        for (String key : BUTTONS) {
            try {
                if (map.hasKey(key) && map.getType(key) == ReadableType.Boolean) {
                    overrides.put(key, map.getBoolean(key));
                }
            } catch (Throwable ignored) {
                // A value of the wrong type counts as false.
            }
        }
    }

    private synchronized boolean overridden(String key) {
        Boolean v = overrides.get(key);
        return v != null && v;
    }

    private boolean clicked(String button) {
        boolean handled = overridden(button);
        WritableMap payload = Arguments.createMap();
        payload.putString("button", button);
        payload.putBoolean("handled", handled);
        emit("onClickMeetingButton", payload);
        return handled;
    }

    private final ZoomUIDelegate uiDelegate = new ZoomUIDelegate() {
        @Override
        public boolean onClickInviteButton(Context context, List<IMeetingInviteMenuItem> items) {
            try { return clicked("invite"); } catch (Throwable t) { return false; }
        }

        @Override
        public void afterMeetingMinimized(Activity activity) {
            // The Activity itself is not serialized: putting it in the ref
            // registry would keep a finished Activity alive.
            try {
                WritableMap payload = Arguments.createMap();
                payload.putArray("args", Arguments.createArray());
                emit("afterMeetingMinimized", payload);
            } catch (Throwable ignored) {
            }
        }

        @Override
        public boolean onClickEndButton() {
            try { return clicked("end"); } catch (Throwable t) { return false; }
        }

        @Override
        public boolean onClickAudioButton() {
            try { return clicked("audio"); } catch (Throwable t) { return false; }
        }

        @Override
        public boolean onClickVideoButton() {
            try { return clicked("video"); } catch (Throwable t) { return false; }
        }

        @Override
        public boolean onClickShareButton() {
            try { return clicked("share"); } catch (Throwable t) { return false; }
        }

        @Override
        public boolean onClickMoreButton() {
            try { return clicked("more"); } catch (Throwable t) { return false; }
        }

        @Override
        public boolean onClickParticipantsButton() {
            try { return clicked("participants"); } catch (Throwable t) { return false; }
        }

        @Override
        public void onVideoSceneChanged(VideoScene oldScene, VideoScene newScene) {
            try {
                WritableMap payload = Arguments.createMap();
                RNZoomUsListeners.putTo(payload, "oldScene", oldScene, 0);
                RNZoomUsListeners.putTo(payload, "newScene", newScene, 0);
                WritableArray all = Arguments.createArray();
                RNZoomUsListeners.pushTo(all, oldScene, 0);
                RNZoomUsListeners.pushTo(all, newScene, 0);
                payload.putArray("args", all);
                emit("onVideoSceneChanged", payload);
            } catch (Throwable ignored) {
            }
        }
    };

    /** Set our ZoomUIDelegate on the SDK if it is initialized. Main thread. */
    void registerUIDelegate() {
        try {
            ZoomSDK sdk = ZoomSDK.getInstance();
            if (sdk == null || !sdk.isInitialized()) return;
            ZoomUIService ui = sdk.getZoomUIService();
            if (ui != null) ui.setZoomUIDelegate(uiDelegate);
        } catch (Throwable t) {
            Log.w(TAG, "setZoomUIDelegate failed: " + t);
        }
    }

    // ---------------------------------------------------------- opt-in prompts

    /** Desired mode per prompt ("reminder", "network"): true = JS answers. */
    private boolean reminderJs = false;
    private boolean networkJs = false;
    /** What is actually registered with the SDK right now. */
    private boolean reminderApplied = false;
    private boolean networkApplied = false;

    /** True if this class owns `prompt`; the caller resolves the promise. */
    static boolean handles(String prompt) {
        return "reminder".equals(prompt) || "network".equals(prompt);
    }

    /** Record the mode and apply it now if the SDK allows. Main thread. */
    synchronized void setPromptMode(String prompt, boolean js) {
        if ("reminder".equals(prompt)) reminderJs = js;
        else if ("network".equals(prompt)) networkJs = js;
        applyPrompts();
    }

    /**
     * Bring the SDK in line with the desired modes. Safe to call often (SDK
     * initialized, meeting status changed): only acts on a difference.
     */
    synchronized void applyPrompts() {
        ZoomSDK sdk;
        try {
            sdk = ZoomSDK.getInstance();
            if (sdk == null || !sdk.isInitialized()) return;
        } catch (Throwable t) {
            return;
        }
        if (reminderJs != reminderApplied) {
            try {
                IReminderHelper helper = sdk.getReminderHelper();
                if (helper != null) {
                    helper.setEvent(reminderJs ? reminderEvent : null);
                    reminderApplied = reminderJs;
                }
            } catch (Throwable t) {
                Log.w(TAG, "reminder setEvent failed: " + t);
            }
        }
        if (networkJs != networkApplied) {
            try {
                if (networkJs) sdk.addNetworkConnectionListener(networkListener);
                else sdk.removeNetworkConnectionListener(networkListener);
                networkApplied = networkJs;
            } catch (Throwable t) {
                Log.w(TAG, "network listener " + (networkJs ? "add" : "remove") + " failed: " + t);
            }
        }
    }

    /** {__ref, __type} only, for a handler pinned until JS answers it. */
    private static WritableMap handlerRef(Object handler) {
        RNZoomUsRefs.pinUntilAnswered(handler);
        // Past the depth limit objectOf returns just __type and __ref.
        return RNZoomUsListeners.objectOf(handler, Integer.MAX_VALUE);
    }

    private final IReminderHelper.IReminderEvent reminderEvent = new IReminderHelper.IReminderEvent() {
        @Override
        public void onReminderNotify(IReminderHelper.IReminderContent content, IReminderHelper.IReminderHandler handler) {
            try {
                WritableMap payload = Arguments.createMap();
                if (content == null) payload.putNull("content");
                else RNZoomUsListeners.putTo(payload, "content", content, 0);
                if (handler == null) payload.putNull("handler");
                else payload.putMap("handler", handlerRef(handler));
                emit("onReminderNotify", payload);
            } catch (Throwable t) {
                Log.w(TAG, "onReminderNotify failed: " + t);
            }
        }
    };

    private final NetworkConnectionListener networkListener = new NetworkConnectionListener() {
        @Override
        public void onProxySettingNotification(ProxySettingHandler handler) {
            emitHandlerEvent("onProxySettingNotification", handler);
        }

        @Override
        public void onSSLCertVerifyNotification(SSLCertVerificationHandler handler) {
            emitHandlerEvent("onSSLCertVerifyNotification", handler);
        }
    };

    private void emitHandlerEvent(String event, Object handler) {
        try {
            WritableMap payload = Arguments.createMap();
            WritableArray all = Arguments.createArray();
            if (handler == null) {
                payload.putNull("handler");
                all.pushNull();
            } else {
                RNZoomUsRefs.pinUntilAnswered(handler);
                // Full getters here (host, port, certificate fields...).
                RNZoomUsListeners.putTo(payload, "handler", handler, 0);
                RNZoomUsListeners.pushTo(all, handler, 0);
            }
            payload.putArray("args", all);
            emit(event, payload);
        } catch (Throwable t) {
            Log.w(TAG, event + " failed: " + t);
        }
    }
}
