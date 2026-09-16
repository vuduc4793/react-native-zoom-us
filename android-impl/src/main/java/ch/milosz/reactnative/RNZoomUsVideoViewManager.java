package ch.milosz.reactnative;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.ViewGroupManager;
import com.facebook.react.uimanager.annotations.ReactProp;

public class RNZoomUsVideoViewManager extends ViewGroupManager<RNZoomUsVideoView> {

  public static final String REACT_CLASS = "RNZoomUsVideoView";

  @Override
  public String getName() {
    return REACT_CLASS;
  }

  @Override
  protected RNZoomUsVideoView createViewInstance(ThemedReactContext themedReactContext) {
    return new RNZoomUsVideoView(themedReactContext);
  }

  @Override
  public void onDropViewInstance(RNZoomUsVideoView view) {
    // Release the GL surface deterministically instead of waiting for the view
    // to be garbage collected; otherwise a remount can come back black.
    view.release();
    super.onDropViewInstance(view);
  }

  // Named to match the codegen-generated RNZoomUsVideoViewManagerInterface, so
  // flipping this manager to Fabric is a one-line `implements` change.
  @ReactProp(name = "layout")
  public void setLayout(RNZoomUsVideoView view, @Nullable ReadableArray layout) {
    view.setZoomLayout(layout);
  }

  /**
   * How the underlying GLSurfaceView is composited:
   *
   *   "mediaOverlay" (default) - above the window surface, below sibling React
   *                              Native views, so controls can be drawn on top.
   *   "onTop"                  - above everything, including React Native views.
   *   "behind"                 - the platform default; only visible when nothing
   *                              paints a background above it.
   */
  @ReactProp(name = "zOrder")
  public void setZOrder(RNZoomUsVideoView view, @Nullable String zOrder) {
    view.setZOrderMode(zOrder == null ? "mediaOverlay" : zOrder);
  }
}
