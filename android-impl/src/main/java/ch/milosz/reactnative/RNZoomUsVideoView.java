package ch.milosz.reactnative;

import android.util.Log;
import android.content.Context;
import android.view.View;

import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;

import us.zoom.sdk.ZoomSDK;
import us.zoom.sdk.MobileRTCVideoUnitRenderInfo;
import us.zoom.sdk.MobileRTCVideoUnitAspectMode;
import us.zoom.sdk.MobileRTCVideoView;
import us.zoom.sdk.MobileRTCVideoViewManager;
import us.zoom.sdk.MeetingStatus;
import us.zoom.sdk.MeetingError;
import us.zoom.sdk.MeetingService;
import us.zoom.sdk.InMeetingService;
import us.zoom.sdk.InMeetingShareController;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;

class RNZoomUsVideoView extends MobileRTCVideoView {

  private final static String TAG = "RNZoomUs";

  /**
   * Every attached instance.
   *
   * The module used to reach its views through UIManagerModule.addUIBlock and a
   * node handle. That does not exist under the New Architecture, so the views
   * keep track of themselves instead -- which works the same under both.
   */
  private static final Set<RNZoomUsVideoView> ATTACHED = new CopyOnWriteArraySet<>();

  /** Refresh every attached view. Must be called on the UI thread. */
  static void updateAll() {
    for (RNZoomUsVideoView view : ATTACHED) {
      try {
        view.update();
      } catch (Exception ex) {
        Log.e(TAG, "Error updating video view", ex);
      }
    }
  }

  private ReadableArray currentLayout = null;
  private Boolean isNewConfig = false;
  private List<Long> lastAttendeeUserList = null;
  private long lastActiveUser = -1;

  public RNZoomUsVideoView(Context context) {
    super(context);

    // MobileRTCVideoView is a RelativeLayout wrapping Zoom's own SDKVideoView
    // (a GLSurfaceView). A bare SurfaceView is composited *behind* the window,
    // so once this view is nested inside anything that paints a background it
    // disappears. Compositing it as a media overlay instead keeps it visible
    // under normal React Native views, which is what lets callers put controls
    // on top of the video.
    setZOrderMediaOverlay(true);
  }

  // React Native does not run the traditional measure/layout pass: it assigns
  // frames straight from the shadow tree and swallows requestLayout() coming
  // from native children. Zoom adds its video surfaces as children of this
  // RelativeLayout at runtime, so without this those children stay at 0x0 and
  // the view renders blank -- which is why it only ever "worked" when it
  // happened to be the full-screen root. Re-running measure+layout on
  // ourselves after every requestLayout() restores normal behaviour and lets
  // the view be nested anywhere.
  private boolean layoutScheduled = false;

  private final Runnable measureAndLayout = new Runnable() {
    @Override
    public void run() {
      layoutScheduled = false;
      measure(
        MeasureSpec.makeMeasureSpec(getWidth(), MeasureSpec.EXACTLY),
        MeasureSpec.makeMeasureSpec(getHeight(), MeasureSpec.EXACTLY)
      );
      layout(getLeft(), getTop(), getRight(), getBottom());
    }
  };

  @Override
  public void requestLayout() {
    super.requestLayout();
    // Zoom re-lays out its surfaces on every frame while video is running, so
    // coalesce: one pass per message-queue turn is enough and keeps this off
    // the hot path.
    if (!layoutScheduled) {
      layoutScheduled = true;
      post(measureAndLayout);
    }
  }

  // MobileRTCVideoView holds a GL context that has to be torn down and rebuilt
  // with the window, otherwise the surface leaks and comes back black after the
  // view is detached and re-attached (backgrounding, tab switches, remounts).
  @Override
  protected void onAttachedToWindow() {
    super.onAttachedToWindow();
    ATTACHED.add(this);
    onResume();
    isNewConfig = true;
    update();
  }

  @Override
  protected void onDetachedFromWindow() {
    ATTACHED.remove(this);
    onPause();
    super.onDetachedFromWindow();
  }

  /** Tear down the GL surface and drop every video unit. */
  public void release() {
    ATTACHED.remove(this);
    try {
      MobileRTCVideoViewManager manager = getVideoViewManager();
      if (manager != null) manager.removeAllVideoUnits();
    } catch (Exception ex) {
      Log.e(TAG, "release() failed", ex);
    }
    currentLayout = null;
    lastAttendeeUserList = null;
    lastActiveUser = -1;
    onPause();
  }

  public void setZOrderMode(String mode) {
    if ("onTop".equals(mode)) {
      setZOrderOnTop(true);
    } else if ("behind".equals(mode)) {
      setZOrderMediaOverlay(false);
      setZOrderOnTop(false);
    } else {
      setZOrderMediaOverlay(true);
    }
  }

  public void setZoomLayout(ReadableArray layout) {
    Log.i(TAG, "set layout");
    currentLayout = layout;
    isNewConfig = true;
    update();
  }

  private List<Long> getAttendeeWithoutMe() {
    ZoomSDK zoomSDK = ZoomSDK.getInstance();

    if (!zoomSDK.isInitialized()) {
      return Collections.emptyList();
    }

    final InMeetingService inMeetingService = zoomSDK.getInMeetingService();

    if (inMeetingService == null) {
      return Collections.emptyList();
    }

    List<Long> users = inMeetingService.getInMeetingUserList();

    if (users == null) {
      return Collections.emptyList();
    }

    // Copy before removing: that list belongs to the SDK, and it hands back an
    // unmodifiable view in some versions -- mutating it throws rather than
    // filtering. Returning a copy also keeps this from ever returning null,
    // which the name does not suggest and callers would have to guard.
    List<Long> withoutMe = new ArrayList<>(users);
    withoutMe.remove(Long.valueOf(inMeetingService.getMyUserID()));
    return withoutMe;
  }

  private long getActiveUser() {
    ZoomSDK zoomSDK = ZoomSDK.getInstance();

    if (!zoomSDK.isInitialized()) {
      return -1;
    }

    final InMeetingService inMeetingService = zoomSDK.getInMeetingService();

    if (inMeetingService == null) {
      return -1;
    }

    // 7.2.1 removed InMeetingService.activeShareUserID(). The replacement reports
    // everyone whose share can be viewed rather than one active sharer, so the
    // first entry is the closest equivalent -- and an empty list now means
    // "nobody is sharing", which the old call expressed as a sentinel id.
    InMeetingShareController shareController = inMeetingService.getInMeetingShareController();
    if (shareController == null) {
      return -1;
    }

    List<Long> sharing = shareController.getViewableSharingUserList();
    if (sharing == null || sharing.isEmpty()) {
      return -1;
    }

    Long first = sharing.get(0);
    return first == null ? -1 : first;
  }

  /**
   * Resolve which participant a unit refers to. An explicit userId wins; the
   * index is only consulted when no id was given, and is bounds-checked because
   * the participant list changes underneath it.
   */
  private static long resolveUser(boolean hasUserId, long userId, List<Long> users, int userIndex) {
    if (hasUserId) return userId;
    if (users == null || userIndex < 0 || userIndex >= users.size()) return -1;
    Long resolved = users.get(userIndex);
    return resolved == null ? -1 : resolved;
  }

  public void update() {
    if (currentLayout == null) {
      Log.e(TAG, "The video view no layout");
      return;
    }
    MobileRTCVideoViewManager manager = getVideoViewManager();
    if (manager == null) {
      Log.e(TAG, "The video view is not initialized completely");
      return;
    }
    try {
      boolean reLyout = isNewConfig;
      long activeUserId = getActiveUser();
      List<Long> users = getAttendeeWithoutMe();
      isNewConfig = false;
      if (lastAttendeeUserList == null || !lastAttendeeUserList.equals(users)) {
        lastAttendeeUserList = users;
        reLyout = true;
      }
      if (activeUserId != lastActiveUser) {
        lastActiveUser = activeUserId;
        reLyout = true;
      }
      if (reLyout) {
        Log.i(TAG, "Re-layout all video unit");
        manager.removeAllVideoUnits();
      }
      for (int i = 0; i < currentLayout.size(); i++) {
        ReadableMap unit = currentLayout.getMap(i);
        String kind = unit.hasKey("kind") ? unit.getString("kind") : "active";
        int x = unit.hasKey("x") ? unit.getInt("x") : 0;
        int y = unit.hasKey("y") ? unit.getInt("y") : 0;
        int width = unit.hasKey("width") ? unit.getInt("width") : 100;
        int height = unit.hasKey("height") ? unit.getInt("height") : 100;
        boolean border = unit.hasKey("border") ? unit.getBoolean("border") : false;
        boolean showUsername = unit.hasKey("showUsername") ? unit.getBoolean("showUsername") : true;
        boolean showAudioOff = unit.hasKey("showAudioOff") ? unit.getBoolean("showAudioOff") : true;
        int userIndex = unit.hasKey("userIndex") ? unit.getInt("userIndex") : 0;
        // A userId addresses a participant directly. userIndex is an offset into
        // the participant list, which shifts as people join and leave, so a unit
        // pinned by index silently starts rendering somebody else.
        boolean hasUserId = unit.hasKey("userId");
        long userId = hasUserId ? (long) unit.getDouble("userId") : -1;
        int aspectMode = unit.hasKey("aspectMode") ? unit.getInt("aspectMode") : 0;
        int background = unit.hasKey("background") ? unit.getInt("background") : 0x000000;
        MobileRTCVideoUnitRenderInfo renderInfo = new MobileRTCVideoUnitRenderInfo(x, y, width, height);
        if (border) {
          renderInfo.is_border_visible = border;
        }
        if (showUsername) {
          renderInfo.is_username_visible = showUsername;
        }
        if (showAudioOff) {
          renderInfo.is_show_audio_off = showAudioOff;
        }
        renderInfo.aspect_mode = aspectMode;
        renderInfo.background_color = background;
        Log.i(TAG, "Layout #" + i + " [kind=" + kind + " x=" + x + " y=" + y + "]");
        switch (kind) {
          case "active":
            if (reLyout) {
              manager.addActiveVideoUnit(renderInfo);
            } else {
              manager.updateActiveVideoUnit(renderInfo);
            }
            break;
          case "preview":
            if (reLyout) {
              manager.addPreviewVideoUnit(renderInfo);
            }
            break;
          case "share": {
            long target = resolveUser(hasUserId, userId, users, userIndex);
            if (target < 0) {
              Log.i(TAG, "No such user for share unit, skip add");
              break;
            }
            if (reLyout) {
              manager.addShareVideoUnit(target, renderInfo);
            } else {
              manager.updateShareVideoUnit(renderInfo);
            }
            break;
          }
          case "attendee": {
            long target = resolveUser(hasUserId, userId, users, userIndex);
            if (target < 0) {
              Log.i(TAG, "No such user for attendee unit, skip add");
              break;
            }
            if (reLyout) {
              manager.addAttendeeVideoUnit(target, renderInfo);
            } else {
              manager.updateAttendeeVideoUnit(target, renderInfo);
            }
          }
            break;
          case "active-share":
            if (reLyout) {
              manager.addShareVideoUnit(activeUserId, renderInfo);
            } else {
              manager.updateShareVideoUnit(renderInfo);
            }
            break;
        }
      }
    } catch (Exception e) {
      Log.e(TAG, e.getMessage());
    }
  }

}
