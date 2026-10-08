// AUTO-GENERATED from the native emitters on both platforms:
//   android-impl/src/main/java/ch/milosz/reactnative/RNZoomUsModule.java
//   src/events/ios-events.json (written by scripts/generate-ios-delegates.py)
// Regenerate with scripts/generate-events.py. Do not edit by hand.
// 78 Android-only, 57 iOS-only, 253 on both.

export interface ZoomMeetingParameter {
  meetingType: string | null;
  isViewOnly: boolean;
  isAutoRecordingLocal: boolean;
  isAutoRecordingCloud: boolean;
  meetingNumber: number;
  meetingTopic: string | null;
  meetingHost: string | null;
}

/** A chat message, as both platforms send it inside onChatMessageNotification. */
export interface ZoomChatMessage {
  chatId: string | null;
  senderId: string | null;
  senderName: string | null;
  receiverId: string | null;
  receiverName: string | null;
  content: string | null;
  date: string | null;
  chatMessageType?: number;
  isMyself?: boolean;
  isPrivate?: boolean;
  isChatToAll?: boolean;
  isChatToAllPanelist?: boolean;
  isChatToWaitingroom?: boolean;
  isComment?: boolean;
  isThread?: boolean;
  /** Same value as threadID; both spellings are filled in. */
  threadId: string | null;
  threadID: string | null;
}

/** Every event the native side can emit, with its payload. */
export interface ZoomEventPayloads {
  /** android + ios */
  askUnMuteAudio: Record<string, never>;
  /** android + ios */
  askUnMuteVideo: Record<string, never>;
  /** ios only */
  backFullScreenMeeting: {
    status: string;
  };
  /** android + ios */
  coHostChanged: {
    userId: number;
    isCoHost: boolean;
  };
  /** android + ios */
  hostChanged: {
    userId: number;
  };
  /** android + ios */
  inMeetingUserCount: {
    count: number;
  };
  /** android + ios */
  myAudioSourceTypeChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** android + ios */
  myAudioStatusChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** android + ios */
  myAudioTypeChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** android + ios */
  myVideoStatusChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** android + ios */
  on3DAvatarItemDataDownloaded: {
    index: number;
    success: number;
    args: unknown[];
  };
  /** android + ios */
  on3DAvatarItemDataDownloading: {
    index: number;
    args: unknown[];
  };
  /** ios only */
  on3DAvatarItemThumbnailsDownloaded: Record<string, never>;
  /** android + ios */
  onAICompanionActiveChangeNotice: {
    b: boolean;
    isActive: boolean;
  };
  /** android + ios */
  onAICompanionFeatureCanNotBeTurnedOff: {
    featuresArr: number[];
    args: unknown[];
  };
  /** android + ios */
  onAICompanionFeatureSwitchRequestResponse: {
    agree: boolean;
    timeout: boolean;
    turnOn: boolean;
    args: unknown[];
  };
  /** android + ios */
  onAICompanionFeatureSwitchRequested: {
    handler: unknown;
    args: unknown[];
    handlerPresent: boolean;
  };
  /** android + ios */
  onAICompanionFeatureTurnOffByParticipant: {
    handler: unknown;
    args: unknown[];
    handlerPresent: boolean;
  };
  /** ios only */
  onActionBeforeDestroyed: {
    sharingID: number;
  };
  /** android + ios */
  onActiveSpeakerVideoUserChanged: {
    userId: number;
    userID: number;
  };
  /** android only */
  onActiveVideoUserChanged: {
    userId: number;
  };
  /** android + ios */
  onAddAnswer: {
    answerID: string | null;
    success: boolean;
    args: unknown[];
  };
  /** android + ios */
  onAddQuestion: {
    questionID: string | null;
    success: boolean;
    args: unknown[];
  };
  /** android only */
  onAllHandsLowered: Record<string, never>;
  /** android + ios */
  onAllowAskQuestionAnonymousStatus: {
    beAllowed: boolean;
    args: unknown[];
  };
  /** android + ios */
  onAllowAskQuestionStatus: {
    bEnabled: boolean;
    args: unknown[];
  };
  /** android only */
  onAllowAttendeeChatResult: {
    args: unknown[];
  };
  /** android only */
  onAllowAttendeeCommentQuestionStatus: {
    args: unknown[];
  };
  /** android + ios */
  onAllowAttendeeRaiseHandStatusChanged: {
    canRaiseHand: boolean;
    args: unknown[];
  };
  /** android + ios */
  onAllowAttendeeViewAllQuestionStatus: {
    beAllowed: boolean;
    args: unknown[];
  };
  /** android + ios */
  onAllowAttendeeViewTheParticipantCountStatusChanged: {
    canViewParticipantCount: boolean;
    args: unknown[];
  };
  /** android only */
  onAllowAttendeeVoteupQuestionStatus: {
    args: unknown[];
  };
  /** android + ios */
  onAllowPanelistStartVideoNotification: {
    args: unknown[];
  };
  /** android + ios */
  onAllowParticipantsRenameNotification: {
    allow: boolean;
  };
  /** android + ios */
  onAllowParticipantsRequestCloudRecording: {
    bAllow: boolean;
    allow: boolean;
  };
  /** ios only */
  onAllowParticipantsShareStatusNotification: {
    allow: boolean;
  };
  /** android + ios */
  onAllowParticipantsShareWhiteBoardNotification: {
    allow: boolean;
  };
  /** android + ios */
  onAllowParticipantsStartVideoNotification: {
    allow: boolean;
  };
  /** android + ios */
  onAllowParticipantsUnmuteSelfNotification: {
    allow: boolean;
  };
  /** android + ios */
  onAllowWebinarReactionStatusChanged: {
    canReaction: boolean;
    args: unknown[];
  };
  /** ios only */
  onAnnotationService: {
    service: unknown;
    servicePresent: boolean;
    shareSourceID: number;
    support: boolean;
  };
  /** android only */
  onAnnotationSupportChanged: {
    args: unknown[];
  };
  /** android + ios */
  onAnnotationToolChanged: {
    tool: number;
  };
  /** android + ios */
  onAnnotationToolTypeChanged: {
    tool: number;
    args: unknown[];
  };
  /** ios only */
  onAppShareSplash: Record<string, never>;
  /** android + ios */
  onAppSignalPanelUpdated: {
    inMeetingAppSignalPanelHandlerPresent: boolean;
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onAttendeeAudioStatusNotification: {
    canTalk: boolean;
    isMuted: boolean;
    userId: number;
    args: unknown[];
  };
  /** android + ios */
  onAttendeePromoteConfirmResult: {
    agree: boolean;
    userId: number;
    args: unknown[];
  };
  /** ios only */
  onAudioOutputChange: Record<string, never>;
  /** android + ios */
  onAvailableLanguageListUpdated: {
    availableLanguageList: unknown;
    args: unknown[];
    availableLanguageListPresent: boolean;
  };
  /** android + ios */
  onAvailableSignLanguageListUpdated: {
    availableSignLanguageList: unknown;
    args: unknown[];
    availableSignLanguageListPresent: boolean;
  };
  /** android + ios */
  onBOEndTimerUpdated: {
    remaining: number;
    isTimesUpNotice: boolean;
  };
  /** android + ios */
  onBOInfoUpdated: {
    boId: string | null;
    args: unknown[];
  };
  /** android + ios */
  onBOListInfoUpdated: {
    args: unknown[];
  };
  /** android + ios */
  onBOOptionChanged: {
    boOption: Record<string, unknown> | null;
    newOption: unknown;
    newOptionPresent: boolean;
  };
  /** ios only */
  onBOStatusChanged: {
    status: number;
  };
  /** android + ios */
  onBOStopCountDown: {
    seconds: number;
  };
  /** android + ios */
  onBOSwitchRequestReceived: {
    boName: string;
    boId: string;
    newBOID: string | null;
    newBOName: string | null;
  };
  /** android + ios */
  onBotAuthorizerRelationChanged: {
    l: number;
    userID: number;
  };
  /** android + ios */
  onBroadcastBOVoiceStatus: {
    start: boolean;
    bStart: boolean;
  };
  /** android only */
  onCallMeStatus: {
    args: unknown[];
  };
  /** android only */
  onCallOutRoomSystemStatusChanged: {
    args: unknown[];
  };
  /** ios only */
  onCallRoomDeviceStateChanged: {
    state: number;
  };
  /** android only */
  onCameraControlRequestReceived: {
    l: number;
    cameraControlRequestType: string | null;
    iCameraControlRequestHandlerPresent: boolean;
  };
  /** android only */
  onCameraControlRequestResult: {
    l: number;
    cameraControlRequestResult: string | null;
  };
  /** ios only */
  onCameraNoPrivilege: Record<string, never>;
  /** android + ios */
  onCaptionStatusChanged: {
    enable: boolean;
    args: unknown[];
  };
  /** android + ios */
  onChatMessageEditNotification: {
    inMeetingChatMessagePresent: boolean;
    chatInfo: unknown;
    chatInfoPresent: boolean;
  };
  /** android + ios */
  onChatMessageNotification: {
    chatInfo: ZoomChatMessage | null;
  };
  /** ios only */
  onChatMsgDeleteNotification: {
    deleteBy: number;
    msgID: string | null;
  };
  /** ios only */
  onCheckCMRPrivilege: {
    result: number;
  };
  /** ios only */
  onClaimHostResult: {
    error: number;
  };
  /** ios only */
  onClickShareScreen: {
    parentVC: unknown;
    parentVCPresent: boolean;
  };
  /** ios only */
  onClickedDialOut: {
    me: boolean;
    parentVC: unknown;
    parentVCPresent: boolean;
  };
  /** ios only */
  onClickedInviteButton: {
    handled: number;
  };
  /** android + ios */
  onClosedCaptionReceived: {
    message: string | string | null;
    senderId: number;
    msgTime: unknown;
    msgTimePresent: boolean;
    speakerID: number;
  };
  /** android + ios */
  onCloudRecordingStorageFull: {
    l: number;
    gracePeriodDate: number;
  };
  /** ios only */
  onCompanionRelationChangedParentUserID: {
    childUserID: number;
    parentUserID: number;
  };
  /** android only */
  onContactPresenceChanged: {
    args: unknown[];
  };
  /** android + ios */
  onCreateBOResponse: {
    BOID: string | null;
    success: boolean;
    args: unknown[];
  };
  /** android only */
  onCreateCompanionRelation: {
    l: number;
    l1: number;
  };
  /** android only */
  onCustom3DAvatarAllElementModelDataDownloaded: {
    args: unknown[];
  };
  /** android only */
  onCustom3DAvatarImageModelDataDownloaded: {
    args: unknown[];
  };
  /** android + ios */
  onCustomWaitingRoomDataUpdated: {
    args: unknown[];
    data: unknown;
    dataPresent: boolean;
  };
  /** android + ios */
  onDeleteAnswer: {
    answerIDArray: string[];
    args: unknown[];
  };
  /** android + ios */
  onDeleteQuestion: {
    questionIDArray: string[];
    args: unknown[];
  };
  /** android + ios */
  onDepromptPanelist2AttendeeResult: {
    errorCode: number;
    args: unknown[];
  };
  /** ios only */
  onDialOutStatusChanged: {
    status: number;
  };
  /** android only */
  onDirectShareStatusUpdate: {
    args: unknown[];
  };
  /** android only */
  onDisallowAttendeeChatResult: {
    args: unknown[];
  };
  /** android + ios */
  onDisallowPanelistStartVideoNotification: {
    args: unknown[];
  };
  /** android only */
  onDocsPermissionChanged: {
    args: unknown[];
  };
  /** ios only */
  onDocsPermissionChangedCreateOption: {
    createOption: number;
    shareOption: number;
  };
  /** android + ios */
  onDocsStatusChanged: {
    sourceInfo: unknown;
    args: unknown[];
    sourceInfoPresent: boolean;
  };
  /** android + ios */
  onE2EEMeetingSecurityCodeChanged: {
    args: unknown[];
  };
  /** android + ios */
  onEmojiFeedbackCanceled: {
    userId: number;
    args: unknown[];
  };
  /** android + ios */
  onEmojiFeedbackReceived: {
    type: number;
    userId: number;
    args: unknown[];
  };
  /** android + ios */
  onEmojiReactionReceived: {
    args: unknown[];
    skinTone: number;
    type: number;
    userId: number;
  };
  /** android + ios */
  onEmojiReactionReceivedInWebinar: {
    type: number;
    args: unknown[];
  };
  /** android only */
  onFailedToRequestSendQuery: {
    args: unknown[];
  };
  /** android only */
  onFailedToStartQuery: {
    args: unknown[];
  };
  /** ios only */
  onFailedToStartShare: Record<string, never>;
  /** android only */
  onFailedToStartSmartSummary: {
    args: unknown[];
  };
  /** android + ios */
  onFileReceived: {
    zoomSDKFileReceiverPresent: boolean;
    receiver: unknown;
    receiverPresent: boolean;
  };
  /** android + ios */
  onFileSendStart: {
    zoomSDKFileSenderPresent: boolean;
    sender: unknown;
    senderPresent: boolean;
  };
  /** android + ios */
  onFileTransferProgress: {
    zoomSDKFileTransferInfoPresent: boolean;
    info: unknown;
    infoPresent: boolean;
  };
  /** android + ios */
  onFocusModeShareTypeChanged: {
    shareType: number | string | null;
  };
  /** android + ios */
  onFocusModeStateChanged: {
    on: boolean;
  };
  /** android + ios */
  onFollowHostVideoOrderChanged: {
    bFollow: boolean;
    follow: boolean;
  };
  /** android + ios */
  onFreeMeetingNeedToUpgrade: {
    type: number | string | null;
    gifUrl: string;
    giftURL: string | null;
  };
  /** android only */
  onFreeMeetingReminder: {
    isHost: boolean;
    canUpgrade: boolean;
    isFirstGift: boolean;
  };
  /** android + ios */
  onFreeMeetingUpgradeToGiftFreeTrialStart: Record<string, never>;
  /** android + ios */
  onFreeMeetingUpgradeToGiftFreeTrialStop: Record<string, never>;
  /** android + ios */
  onFreeMeetingUpgradeToProMeeting: Record<string, never>;
  /** android + ios */
  onFreeMeetingUpgradedToProMeeting: Record<string, never>;
  /** android + ios */
  onGetRightAnswerListPrivilege: {
    bCan: boolean;
    args: unknown[];
  };
  /** android + ios */
  onGrantCoOwnerPrivilegeChanged: {
    canGrantOther: boolean;
  };
  /** android + ios */
  onHasAdminRightsNotification: {
    adminPresent: boolean;
    admin: unknown;
  };
  /** android + ios */
  onHasAssistantRightsNotification: {
    assistantPresent: boolean;
    assistant: unknown;
  };
  /** ios only */
  onHasAttendeeRightsNotification: {
    attendee: unknown;
    attendeePresent: boolean;
  };
  /** android + ios */
  onHasCreatorRightsNotification: {
    creatorPresent: boolean;
    creator: unknown;
  };
  /** android + ios */
  onHasDataHelperRightsNotification: {
    dataHelperPresent: boolean;
    dataHelper: unknown;
  };
  /** android + ios */
  onHelpRequestHandleResultReceived: {
    result: string | null;
    eResult: number;
  };
  /** android + ios */
  onHelpRequestReceived: {
    strUserID: string | string | null;
  };
  /** android + ios */
  onHostInviteReturnToMainSession: {
    hostName: string | string | null;
    replyHandlerPresent: boolean;
    replyHandler: unknown;
  };
  /** android + ios */
  onHostJoinedThisBOMeeting: Record<string, never>;
  /** android + ios */
  onHostLeaveThisBOMeeting: Record<string, never>;
  /** android + ios */
  onHostUnsupportedStopNotesRequest: {
    args: unknown[];
  };
  /** android + ios */
  onHostVideoOrderUpdated: {
    orderList: number[];
    orderArr: number[];
  };
  /** android + ios */
  onInMeetingUserAvatarPathUpdated: {
    userId: number;
    userID: number;
  };
  /** android + ios */
  onIndicatorItemReceived: {
    inMeetingIndicatorHandler: unknown;
    args: unknown[];
    inMeetingIndicatorHandlerPresent: boolean;
  };
  /** android + ios */
  onIndicatorItemRemoved: {
    inMeetingIndicatorHandler: unknown;
    args: unknown[];
    inMeetingIndicatorHandlerPresent: boolean;
  };
  /** android + ios */
  onInterpretationStart: {
    args: unknown[];
  };
  /** android + ios */
  onInterpretationStop: {
    args: unknown[];
  };
  /** android + ios */
  onInterpreterActiveLanguageChanged: {
    activeLanID: number;
    userID: number;
    args: unknown[];
  };
  /** android + ios */
  onInterpreterLanguageChanged: {
    lanID1: number;
    lanID2: number;
    args: unknown[];
  };
  /** android + ios */
  onInterpreterLanguagesUpdated: {
    availableLanguages: unknown;
    args: unknown[];
    availableLanguagesPresent: boolean;
  };
  /** android + ios */
  onInterpreterListChanged: {
    args: unknown[];
  };
  /** android + ios */
  onInterpreterRoleChanged: {
    isInterpreter: boolean;
    userID: number;
    args: unknown[];
  };
  /** android only */
  onInvalidReclaimHostkey: Record<string, never>;
  /** android only */
  onInviteCallOutUserStatus: {
    args: unknown[];
  };
  /** ios only */
  onJBHWaitingWithCmd: {
    cmd: number;
  };
  /** ios only */
  onJoinMeetingConfirmed: Record<string, never>;
  /** ios only */
  onJoinMeetingInfoRequired: {
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onJoinMeetingNeedUserInfo: {
    iMeetingInputUserInfoHandlerPresent: boolean;
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android only */
  onJoinWebinarNeedUserNameAndEmail: {
    handlerPresent: boolean;
  };
  /** android + ios */
  onLiveStreamReminderStatusChangeFailed: {
    args: unknown[];
  };
  /** android + ios */
  onLiveStreamReminderStatusChanged: {
    enable: boolean;
    args: unknown[];
  };
  /** android + ios */
  onLiveStreamReminderStatusChangedFailed: Record<string, never>;
  /** android + ios */
  onLiveStreamStatusChange: {
    liveStreamStatus: number;
    args: unknown[];
  };
  /** android + ios */
  onLiveTranscriptionMsgError: {
    speakLanguage: unknown;
    transcriptLanguage: unknown;
    args: unknown[];
    speakLanguagePresent: boolean;
    transcriptLanguagePresent: boolean;
  };
  /** android + ios */
  onLiveTranscriptionMsgInfoReceived: {
    messageInfo: unknown;
    messageInfoPresent: boolean;
  };
  /** android + ios */
  onLiveTranscriptionMsgReceived: {
    messageInfo: unknown;
    args: unknown[];
  };
  /** android + ios */
  onLiveTranscriptionStatus: {
    status: number;
    args: unknown[];
  };
  /** android only */
  onLocalRecordingPrivilegeRequested: {
    handlerPresent: boolean;
  };
  /** android + ios */
  onLocalRecordingStatus: {
    userId: number;
    recordingStatus: string | null;
    status: number;
  };
  /** android + ios */
  onLocalVideoOrderUpdated: {
    localOrderList: number[];
    localOrderArr: number[];
  };
  /** android + ios */
  onLostAdminRightsNotification: Record<string, never>;
  /** android + ios */
  onLostAssistantRightsNotification: Record<string, never>;
  /** android + ios */
  onLostAttendeeRightsNotification: Record<string, never>;
  /** android + ios */
  onLostCreatorRightsNotification: Record<string, never>;
  /** android + ios */
  onLostDataHelperRightsNotification: Record<string, never>;
  /** android + ios */
  onLowOrRaiseHandStatusChanged: {
    userId: number;
    isRaisedHand: boolean;
  };
  /** android + ios */
  onManualCaptionStatusChanged: {
    bEnabled: boolean;
    args: unknown[];
  };
  /** android only */
  onMeetingAcceptedByOtherDevice: {
    args: unknown[];
  };
  /** android + ios */
  onMeetingActiveVideo: {
    userId: number;
  };
  /** android + ios */
  onMeetingCoHostChange: {
    isCoHost: boolean;
    userID: number;
  };
  /** android only */
  onMeetingDeclinedByOtherDevice: {
    args: unknown[];
  };
  /** android only */
  onMeetingDeviceListChanged: {
    args: unknown[];
  };
  /** ios only */
  onMeetingEndedReason: {
    reason: number;
  };
  /** ios only */
  onMeetingError: {
    error: number;
    errorCode: number;
    message: string | null;
  };
  /** android only */
  onMeetingFail: {
    errorCode: number;
    internalErrorCode: number;
  };
  /** android + ios */
  onMeetingFullToWatchLiveStream: {
    s: string;
    liveStreamUrl: string | null;
  };
  /** android + ios */
  onMeetingHostChange: {
    hostId: number;
  };
  /** android only */
  onMeetingInvitationCanceled: {
    args: unknown[];
  };
  /** android only */
  onMeetingInvitationDeclined: {
    args: unknown[];
  };
  /** android + ios */
  onMeetingLockStatus: {
    isLock: boolean;
  };
  /** android only */
  onMeetingNeedCloseOtherMeeting: {
    handlerPresent: boolean;
  };
  /** android only */
  onMeetingNeedConfirmPreview: {
    inMeetingPreviewHandlerPresent: boolean;
  };
  /** android only */
  onMeetingNeedPasswordOrDisplayName: {
    needPassword: boolean;
    needDisplayName: boolean;
    handlerPresent: boolean;
  };
  /** android + ios */
  onMeetingParameterNotification: {
    meetingParameter: ZoomMeetingParameter | null;
    meetingParam: unknown;
    meetingParamPresent: boolean;
  };
  /** android + ios */
  onMeetingQAStatusChanged: {
    isMeetingQAFeatureOn: boolean;
    args: unknown[];
  };
  /** ios only */
  onMeetingReady: Record<string, never>;
  /** android + ios */
  onMeetingStateChange: {
    state: number;
  };
  /** android + ios */
  onMeetingTopicChanged: {
    s: string;
    meetingTopic: string | null;
  };
  /** ios only */
  onMicrophoneNoPrivilege: Record<string, never>;
  /** android + ios */
  onMicrophoneStatusError: {
    error: number | string | null;
  };
  /** ios only */
  onMobileRTCAuthExpired: Record<string, never>;
  /** ios only */
  onMobileRTCAuthReturn: {
    returnValue: number;
  };
  /** ios only */
  onMobileRTCLoginResult: {
    resultValue: number;
  };
  /** ios only */
  onMobileRTCLogoutReturn: {
    returnValue: number;
  };
  /** android + ios */
  onMuteOnEntryStatusChange: {
    b: boolean;
    bEnabled: boolean;
  };
  /** android + ios */
  onMyAudioSourceTypeChanged: {
    type: number;
  };
  /** ios only */
  onMyAudioStateChange: Record<string, never>;
  /** android only */
  onMyNotesCanStartChanged: {
    args: unknown[];
  };
  /** android only */
  onMyNotesStatusChanged: {
    args: unknown[];
  };
  /** ios only */
  onMyVideoStateChange: Record<string, never>;
  /** android only */
  onNeedRealNameAuthMeetingNotification: {
    args: unknown[];
  };
  /** android + ios */
  onNewBroadcastMessageReceived: {
    message: string;
    senderId: number;
    senderName: string | string | null;
    broadcastMsg: string | null;
    senderID: number;
  };
  /** ios only */
  onNoHostMeetingWillTerminate: {
    minutes: number;
  };
  /** android + ios */
  onNotificationServiceStatus: {
    error: number;
    status: number;
    args: unknown[];
  };
  /** ios only */
  onOngoingShareStopped: Record<string, never>;
  /** ios only */
  onOptimizingShareForVideoClipStatusChanged: {
    shareInfo: unknown;
    shareInfoPresent: boolean;
  };
  /** android + ios */
  onOriginalLanguageMsgReceived: {
    messageInfo: unknown;
    args: unknown[];
    messageInfoPresent: boolean;
  };
  /** android + ios */
  onPSUserStatusChanged: {
    isStart: boolean;
    userId: number;
    args: unknown[];
  };
  /** android only */
  onParingRoomSystemResult: {
    args: unknown[];
  };
  /** android + ios */
  onParticipantProfilePictureStatusChange: {
    b: boolean;
    hidden: boolean;
  };
  /** android only */
  onPermissionRequested: {
    permissions: string[];
  };
  /** android + ios */
  onPollingActionResult: {
    actionType: number;
    bSuccess: boolean;
    errorMsg: string | null;
    pollingID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onPollingElapsedTime: {
    pollingID: string | null;
    uElapsedtime: number;
    args: unknown[];
  };
  /** android + ios */
  onPollingInactive: {
    args: unknown[];
  };
  /** android + ios */
  onPollingListUpdated: {
    args: unknown[];
  };
  /** android + ios */
  onPollingQuestionImageDownloaded: {
    path: string | null;
    questionID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onPollingResultUpdated: {
    pollingID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onPollingStatusChanged: {
    pollingID: string | null;
    status: number;
    args: unknown[];
  };
  /** android + ios */
  onPromptAttendee2PanelistResult: {
    errorCode: number;
    args: unknown[];
  };
  /** android + ios */
  onQAConnectStarted: {
    args: unknown[];
  };
  /** android + ios */
  onQAConnected: {
    connected: boolean;
    args: unknown[];
  };
  /** android only */
  onQueryEnableActionCallback: {
    args: unknown[];
  };
  /** android only */
  onQuerySettingChanged: {
    args: unknown[];
  };
  /** android only */
  onQueryStateEnabledButNotStarted: {
    args: unknown[];
  };
  /** android only */
  onQueryStateNotSupported: {
    args: unknown[];
  };
  /** android only */
  onQueryStateStarted: {
    args: unknown[];
  };
  /** android only */
  onQueryStateSupportedButDisabled: {
    args: unknown[];
  };
  /** android + ios */
  onQuestionMarkedAsDismissed: {
    questionID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onRawLiveStreamPrivilegeChanged: {
    hasPrivilege: boolean;
    args: unknown[];
  };
  /** android + ios */
  onRawLiveStreamPrivilegeRequestTimeout: {
    args: unknown[];
  };
  /** android + ios */
  onRawLiveStreamPrivilegeRequested: {
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onReceiveAnswer: {
    answerID: string | null;
    args: unknown[];
  };
  /** android only */
  onReceiveInvitationToMeeting: {
    args: unknown[];
  };
  /** android only */
  onReceiveOfflineNotificationPubKey: {
    args: unknown[];
  };
  /** android only */
  onReceiveQueryAnswer: {
    args: unknown[];
  };
  /** android + ios */
  onReceiveQuestion: {
    questionID: string | null;
    args: unknown[];
  };
  /** android only */
  onReceiveRequestToEnableQuery: {
    args: unknown[];
  };
  /** android only */
  onReceiveRequestToSendQuery: {
    args: unknown[];
  };
  /** android only */
  onReceiveRequestToStartQuery: {
    args: unknown[];
  };
  /** android + ios */
  onRecordingStatus: {
    status: number | string | null;
  };
  /** android only */
  onRegisterOfflineNotification: {
    args: unknown[];
  };
  /** android + ios */
  onRemoveBOResponse: {
    BOID: string | null;
    success: boolean;
    args: unknown[];
  };
  /** android + ios */
  onRemoveCompanionRelation: {
    l: number;
    childUserID: number;
  };
  /** android + ios */
  onReopenQuestion: {
    questionID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onRequestCloudRecordingResponse: {
    status: number;
    args: unknown[];
  };
  /** android only */
  onRequestContactDetailInfo: {
    args: unknown[];
  };
  /** android + ios */
  onRequestForLiveTranscriptReceived: {
    bAnonymous: boolean;
    requesterUserId: number;
    args: unknown[];
  };
  /** android only */
  onRequestLiveTranscriptionStatusChange: {
    args: unknown[];
  };
  /** android + ios */
  onRequestLocalRecordingPrivilegeChanged: {
    status: number | string | null;
  };
  /** ios only */
  onRequestLocalRecordingPrivilegeReceived: {
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onRequestRawLiveStreamPrivilegeRequested: {
    handler: unknown;
    args: unknown[];
  };
  /** android + ios */
  onRequestSignInterpreterToTalk: {
    args: unknown[];
  };
  /** android only */
  onRequestStarContact: {
    args: unknown[];
  };
  /** android only */
  onRetrieveSMSVerificationCodeResultNotification: {
    args: unknown[];
  };
  /** android + ios */
  onRevokeUpvoteQuestion: {
    orderChanged: boolean;
    questionID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onSelfAllowTalkNotification: {
    args: unknown[];
  };
  /** android + ios */
  onSelfDisallowTalkNotification: {
    args: unknown[];
  };
  /** ios only */
  onSendPairingCodeStateChanged: {
    meetingNumber: number;
    state: number;
  };
  /** android only */
  onSendQueryPrivilegeChanged: {
    args: unknown[];
  };
  /** ios only */
  onShareContentChanged: {
    shareInfo: unknown;
    shareInfoPresent: boolean;
  };
  /** android + ios */
  onShareFromMainSession: {
    l: number;
    sharingStatus: string | null;
    iShareActionPresent: boolean;
    shareAction: unknown;
    shareActionPresent: boolean;
    sharingID: number;
    status: number;
  };
  /** android only */
  onShareMeetingChatStatusChanged: {
    start: boolean;
  };
  /** android + ios */
  onShareSettingTypeChanged: {
    type: string | null;
  };
  /** android only */
  onShareUserReceivingStatus: {
    userId: number;
  };
  /** ios only */
  onSharingContentStartReceiving: Record<string, never>;
  /** android + ios */
  onSignInterpretationStatusChange: {
    status: number;
  };
  /** android + ios */
  onSignInterpretationStatusChanged: {
    status: number;
    args: unknown[];
  };
  /** android + ios */
  onSignInterpreterLanguageChanged: {
    args: unknown[];
  };
  /** android + ios */
  onSignInterpreterListChanged: {
    args: unknown[];
  };
  /** android + ios */
  onSignInterpreterRoleChanged: {
    args: unknown[];
  };
  /** android only */
  onSilentModeChanged: {
    inSilentMode: boolean;
  };
  /** android + ios */
  onSinkAllowAttendeeChatNotification: {
    privilege: number;
    currentPrivilege: number;
  };
  /** android + ios */
  onSinkAttendeeChatPriviledgeChanged: {
    currentPrivilege: number;
  };
  /** android + ios */
  onSinkAttendeeChatPrivilegeChanged: {
    i: number;
  };
  /** android + ios */
  onSinkAttendeePromoteConfirmResult: {
    agree: boolean;
    userId: number;
  };
  /** android + ios */
  onSinkDePromptPanelist2AttendeeResult: {
    errorCode: number;
  };
  /** android + ios */
  onSinkDeleteAnswer: {
    answerIDArray: string[];
  };
  /** android + ios */
  onSinkDeleteQuestion: {
    questionIDArray: string[];
  };
  /** android + ios */
  onSinkJoin3rdPartyTelephonyAudio: {
    s: string;
    audioInfo: string | null;
  };
  /** android + ios */
  onSinkLiveTranscriptionStatus: {
    status: number;
  };
  /** ios only */
  onSinkLowerAllHands: Record<string, never>;
  /** android + ios */
  onSinkMeetingActiveVideo: {
    userID: number;
  };
  /** android + ios */
  onSinkMeetingAudioRequestUnmuteByHost: Record<string, never>;
  /** android + ios */
  onSinkMeetingAudioStatusChange: {
    audioStatus: number;
    userID: number;
  };
  /** android + ios */
  onSinkMeetingAudioTypeChange: {
    userID: number;
  };
  /** android + ios */
  onSinkMeetingMyAudioTypeChange: Record<string, never>;
  /** ios only */
  onSinkMeetingPreviewStopped: Record<string, never>;
  /** ios only */
  onSinkMeetingShowMinimizeMeetingOrBackZoomUI: {
    state: number;
  };
  /** android + ios */
  onSinkMeetingUserJoin: {
    userID: number;
  };
  /** android + ios */
  onSinkMeetingUserLeft: {
    userID: number;
  };
  /** android + ios */
  onSinkMeetingUserLowerHand: {
    userID: number;
  };
  /** android + ios */
  onSinkMeetingUserRaiseHand: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingVideoQualityChanged: {
    qality: number;
    userID: number;
  };
  /** android + ios */
  onSinkMeetingVideoRequestUnmuteByHost: Record<string, never>;
  /** android + ios */
  onSinkMeetingVideoStatusChange: {
    userID: number;
    videoStatus: number;
  };
  /** ios only */
  onSinkPanelistCapacityExceed: Record<string, never>;
  /** android + ios */
  onSinkPanelistChatPrivilegeChanged: {
    privilege: number | string | null;
  };
  /** android + ios */
  onSinkPromptAttendee2PanelistResult: {
    errorCode: number;
  };
  /** android + ios */
  onSinkQAAddAnswer: {
    answerID: string | null;
    success: boolean;
  };
  /** android + ios */
  onSinkQAAddQuestion: {
    questionID: string | null;
    success: boolean;
  };
  /** android + ios */
  onSinkQAAllowAskQuestionAnonymouslyNotification: {
    beAllowed: boolean;
  };
  /** ios only */
  onSinkQAAllowAttendeeAnswerQuestionNotification: {
    beAllowed: boolean;
  };
  /** ios only */
  onSinkQAAllowAttendeeUpVoteQuestionNotification: {
    beAllowed: boolean;
  };
  /** android + ios */
  onSinkQAAllowAttendeeViewAllQuestionNotification: {
    beAllowed: boolean;
  };
  /** android + ios */
  onSinkQAConnectStarted: Record<string, never>;
  /** android + ios */
  onSinkQAConnected: {
    connected: boolean;
  };
  /** ios only */
  onSinkQAOpenQuestionChanged: {
    count: number;
  };
  /** android + ios */
  onSinkQuestionMarkedAsDismissed: {
    questionID: string | null;
  };
  /** android + ios */
  onSinkReceiveAnswer: {
    answerID: string | null;
  };
  /** android + ios */
  onSinkReceiveQuestion: {
    questionID: string | null;
  };
  /** android + ios */
  onSinkReopenQuestion: {
    questionID: string | null;
  };
  /** android + ios */
  onSinkRequestForLiveTranscriptReceived: {
    bAnonymous: boolean;
    requesterUserId: number;
  };
  /** android + ios */
  onSinkRevokeVoteupQuestion: {
    orderChanged: boolean;
    questionID: string | null;
  };
  /** android + ios */
  onSinkSelfAllowTalkNotification: Record<string, never>;
  /** android + ios */
  onSinkSelfDisallowTalkNotification: Record<string, never>;
  /** android + ios */
  onSinkShareSettingTypeChanged: {
    shareSettingType: number;
  };
  /** ios only */
  onSinkShareSizeChange: {
    userID: number;
  };
  /** ios only */
  onSinkSharingStatus: {
    shareInfo: unknown;
    shareInfoPresent: boolean;
  };
  /** android + ios */
  onSinkUserEndLiving: {
    questionID: string | null;
  };
  /** android + ios */
  onSinkUserLivingReply: {
    questionID: string | null;
  };
  /** android + ios */
  onSinkUserNameChanged: {
    userNameChangedArr: number[];
  };
  /** android + ios */
  onSinkVoteupQuestion: {
    orderChanged: boolean;
    questionID: string | null;
  };
  /** android + ios */
  onSinkWebinarNeedRegister: {
    registerURL: string | null;
  };
  /** android only */
  onSmartSummaryStartRequestReceived: {
    args: unknown[];
  };
  /** android only */
  onSmartSummaryStateEnabledButNotStarted: {
    args: unknown[];
  };
  /** android only */
  onSmartSummaryStateNotSupported: {
    args: unknown[];
  };
  /** android only */
  onSmartSummaryStateStarted: {
    args: unknown[];
  };
  /** android only */
  onSmartSummaryStateSupportedButDisabled: {
    args: unknown[];
  };
  /** android + ios */
  onSpokenLanguageChanged: {
    spokenLanguage: unknown;
    args: unknown[];
    spokenLanguagePresent: boolean;
  };
  /** android + ios */
  onSpotlightVideoChange: {
    on: boolean;
  };
  /** android + ios */
  onSpotlightVideoChanged: {
    userList: number[];
  };
  /** ios only */
  onSpotlightVideoUserChange: {
    spotlightedUserList: number[];
  };
  /** android only */
  onStarContactListChanged: {
    args: unknown[];
  };
  /** ios only */
  onStartBOError: {
    errType: number;
  };
  /** android + ios */
  onStartBOResponse: {
    bSuccess: boolean;
    success: boolean;
  };
  /** android + ios */
  onStartCaptionsRequestApproved: {
    args: unknown[];
  };
  /** android + ios */
  onStartCaptionsRequestReceived: {
    handler: unknown;
    args: unknown[];
    handlerPresent: boolean;
  };
  /** android + ios */
  onStartCloudRecordingRequested: {
    handler: unknown;
    args: unknown[];
    handlerPresent: boolean;
  };
  /** android + ios */
  onStopBOResponse: {
    bSuccess: boolean;
    success: boolean;
  };
  /** ios only */
  onSubscribeUserFail: {
    errorCode: number;
    size: number;
    userId: number;
  };
  /** android + ios */
  onSuspendParticipantsActivities: Record<string, never>;
  /** android + ios */
  onTalkPrivilegeChanged: {
    hasPrivilege: boolean;
    args: unknown[];
  };
  /** android only */
  onTransferMeetingResult: {
    args: unknown[];
  };
  /** android + ios */
  onUVCCameraStatusChange: {
    cameraId: string;
    status: number | string | null;
  };
  /** android + ios */
  onUnAssignedUserUpdated: {
    args: unknown[];
  };
  /** android only */
  onUnRegisterOfflineNotification: {
    args: unknown[];
  };
  /** android + ios */
  onUpdateBONameResponse: {
    BOID: string | null;
    success: boolean;
    args: unknown[];
  };
  /** ios only */
  onUpgradeFreeMeetingResult: {
    result: number;
  };
  /** android + ios */
  onUpvoteQuestion: {
    orderChanged: boolean;
    questionID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onUserAudioStatusChanged: {
    userId: number;
    audioStatus: number;
    audioStatusName: string | null;
  };
  /** android + ios */
  onUserAudioTypeChanged: {
    userId: number;
  };
  /** android + ios */
  onUserConfirmRecoverMeeting: {
    iRecoverMeetingHandlePresent: boolean;
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onUserConfirmToStartArchive: {
    iMeetingArchiveConfirmHandlerPresent: boolean;
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onUserEndLiving: {
    questionID: string | null;
    args: unknown[];
  };
  /** android only */
  onUserGetRemoteControlPrivilege: {
    args: unknown[];
  };
  /** android + ios */
  onUserLivingReply: {
    questionID: string | null;
    args: unknown[];
  };
  /** android + ios */
  onUserNamesChanged: {
    userList: number[];
  };
  /** android + ios */
  onUserNetworkStatusChanged: {
    componentType: string | null;
    quality: string | null;
    userId: number;
    isMyself: boolean;
    level: number;
    type: number;
    uplink: boolean;
    userID: number;
  };
  /** android + ios */
  onUserRawLiveStreamPrivilegeChanged: {
    hasPrivilege: number;
    userId: number;
    args: unknown[];
  };
  /** android + ios */
  onUserRawLiveStreamingStatusChanged: {
    liveStreamList: unknown;
    args: unknown[];
    liveStreamListPresent: boolean;
  };
  /** android + ios */
  onUserThresholdReachedForLiveStream: {
    percent: number;
    args: unknown[];
  };
  /** android + ios */
  onUserVideoStatusChanged: {
    userId: number;
    videoStatus: number;
    videoStatusName: string | null;
  };
  /** android only */
  onVerifySMSVerificationCodeResultNotification: {
    args: unknown[];
  };
  /** android + ios */
  onVideoAlphaChannelStatusChanged: {
    isAlphaModeOn: boolean;
    alphaChannelOn: boolean;
  };
  /** android + ios */
  onVirtualNameTagRosterInfoUpdated: {
    l: number;
    userID: number;
  };
  /** android + ios */
  onVirtualNameTagStatusChanged: {
    b: boolean;
    l: number;
    bOn: boolean;
    userID: number;
  };
  /** android + ios */
  onWaitingRoomEntranceEnabled: {
    enabled: boolean;
    args: unknown[];
  };
  /** android + ios */
  onWaitingRoomPresetAudioStatusChanged: {
    audioCanTurnOn: boolean;
    args: unknown[];
  };
  /** android + ios */
  onWaitingRoomPresetVideoStatusChanged: {
    videoCanTurnOn: boolean;
    args: unknown[];
  };
  /** ios only */
  onWaitingRoomStatusChange: {
    needWaiting: boolean;
  };
  /** android + ios */
  onWaitingRoomUserJoin: {
    userId: number;
    args: unknown[];
  };
  /** android + ios */
  onWaitingRoomUserLeft: {
    userId: number;
    args: unknown[];
  };
  /** android + ios */
  onWaitingRoomUserNameChanged: {
    userID: number;
    userName: string | null;
    args: unknown[];
  };
  /** android + ios */
  onWebPreAssignBODataDownloadStatusChanged: {
    status: number;
    args: unknown[];
  };
  /** android + ios */
  onWebinarNeedInputScreenName: {
    inMeetingEventHandlerPresent: boolean;
    handler: unknown;
    handlerPresent: boolean;
  };
  /** android + ios */
  onWebinarNeedRegister: {
    registerUrl: string;
  };
  /** android + ios */
  onWhiteboardSettingsChanged: {
    createOption: number;
    enable: boolean;
    shareOption: number;
    args: unknown[];
  };
  /** android + ios */
  onWhiteboardStatusChanged: {
    status: number;
    args: unknown[];
  };
  /** android only */
  onZoomAuthIdentityExpired: Record<string, never>;
  /** android + ios */
  onZoomIdentityExpired: {
    args: unknown[];
  };
  /** android only */
  onZoomSDKLoginResult: {
    args: unknown[];
  };
  /** android only */
  onZoomSDKLogoutResult: {
    args: unknown[];
  };
  /** android only */
  remoteControlStarted: {
    args: unknown[];
  };
  /** android only */
  screenShareError: Record<string, never>;
  /** android only */
  screenShareStarted: Record<string, never>;
  /** android only */
  screenShareStopped: Record<string, never>;
  /** android only */
  screenShareSuccess: Record<string, never>;
  /** ios only */
  showMinimizeMeeting: {
    status: string;
  };
  /** android + ios */
  success: {
    status: string;
  };
  /** android + ios */
  userJoin: {
    userList: number[];
  };
  /** android + ios */
  userLeave: {
    userList: number[];
  };
}

export type ZoomEventName = keyof ZoomEventPayloads;

/** Payload as delivered on the wire: the event name travels with it. */
export type ZoomEvent<K extends ZoomEventName = ZoomEventName> = {
  [E in K]: ZoomEventPayloads[E] & { event: E; channel?: string };
}[K];
