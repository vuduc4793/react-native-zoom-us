package ch.milosz.reactnative.loader;

import android.util.Log;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * The package autolinking puts in the base app.
 *
 * It always provides the loader, and additionally delegates to the real
 * ch.milosz.reactnative.RNZoomUsPackage once the on-demand module carrying the
 * Zoom SDK has been installed. Loading it reflectively is what lets the base app
 * compile without the SDK on its classpath.
 *
 * Installing the module ends in a process restart, so by the time this runs the
 * class is either genuinely loadable or genuinely absent -- there is no
 * half-installed state to handle.
 */
public class RNZoomUsLoaderPackage implements ReactPackage {

    private static final String TAG = "RNZoomUsLoader";
    private static final String IMPL_PACKAGE = "ch.milosz.reactnative.RNZoomUsPackage";

    private ReactPackage implementation;
    private boolean implementationResolved;

    private ReactPackage implementation(ReactApplicationContext context) {
        if (implementationResolved) return implementation;
        implementationResolved = true;

        if (!RNZoomUsLoaderModule.isModuleInstalled(context)) {
            Log.i(TAG, "Zoom module not installed; only the loader is available");
            return null;
        }

        try {
            implementation = (ReactPackage) Class.forName(IMPL_PACKAGE)
                    .getDeclaredConstructor()
                    .newInstance();
        } catch (Throwable t) {
            // Reported as installed but not loadable: most often the process has
            // not restarted since the install.
            Log.e(TAG, "Zoom module is installed but " + IMPL_PACKAGE + " could not be loaded. "
                    + "Has the process restarted since installing?", t);
        }
        return implementation;
    }

    @NonNull
    @Override
    public List<NativeModule> createNativeModules(@NonNull ReactApplicationContext context) {
        List<NativeModule> modules = new ArrayList<>();
        modules.add(new RNZoomUsLoaderModule(context));

        ReactPackage impl = implementation(context);
        if (impl != null) modules.addAll(impl.createNativeModules(context));
        return modules;
    }

    @NonNull
    @Override
    public List<ViewManager> createViewManagers(@NonNull ReactApplicationContext context) {
        ReactPackage impl = implementation(context);
        return impl != null ? impl.createViewManagers(context) : Collections.emptyList();
    }
}
