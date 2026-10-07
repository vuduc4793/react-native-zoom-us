// AUTO-GENERATED from the native emitters on both platforms:
//   android-impl/src/main/java/ch/milosz/reactnative/RNZoomUsModule.java
//   src/events/ios-events.json (written by scripts/generate-ios-delegates.py)
// Regenerate with scripts/generate-events.py. Do not edit by hand.
// 42 Android-only, 200 iOS-only, 54 on both.

export interface ZoomMeetingParameter {
  meetingType: string | null;
  isViewOnly: boolean;
  isAutoRecordingLocal: boolean;
  isAutoRecordingCloud: boolean;
  meetingNumber: number;
  meetingTopic: string | null;
  meetingHost: string | null;
}

/** Every event the native side can emit, with its payload. */
export interface ZoomEventPayloads {
  /** android only */
  askUnMuteAudio: Record<string, never>;
  /** android only */
  askUnMuteVideo: Record<string, never>;
  /** android only */
  coHostChanged: {
    userId: number;
  };
  /** android only */
  hostChanged: {
    userId: number;
  };
  /** android only */
  inMeetingUserCount: {
    userList: number;
  };
  /** android only */
  myAudioSourceTypeChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** android only */
  myAudioStatusChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** android only */
  myVideoStatusChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  /** ios only */
  on3DAvatarItemDataDownloaded: {
    index: number;
    success: number;
  };
  /** ios only */
  on3DAvatarItemDataDownloading: {
    index: number;
  };
  /** ios only */
  on3DAvatarItemThumbnailsDownloaded: Record<string, never>;
  /** android + ios */
  onAICompanionActiveChangeNotice: {
    b: boolean;
    isActive: boolean;
  };
  /** ios only */
  onAICompanionFeatureCanNotBeTurnedOff: {
    featuresArr: number[];
  };
  /** ios only */
  onAICompanionFeatureSwitchRequestResponse: {
    agree: boolean;
    timeout: boolean;
    turnOn: boolean;
  };
  /** ios only */
  onAICompanionFeatureSwitchRequested: {
    handlerPresent: boolean;
  };
  /** ios only */
  onAICompanionFeatureTurnOffByParticipant: {
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
  /** android only */
  onAllHandsLowered: Record<string, never>;
  /** ios only */
  onAllowAskQuestionStatus: {
    bEnabled: boolean;
  };
  /** ios only */
  onAllowAttendeeRaiseHandStatusChanged: {
    canRaiseHand: boolean;
  };
  /** ios only */
  onAllowAttendeeViewTheParticipantCountStatusChanged: {
    canViewParticipantCount: boolean;
  };
  /** ios only */
  onAllowPanelistStartVideoNotification: Record<string, never>;
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
  /** ios only */
  onAllowWebinarReactionStatusChanged: {
    canReaction: boolean;
  };
  /** ios only */
  onAnnotationService: {
    servicePresent: boolean;
    shareSourceID: number;
    support: boolean;
  };
  /** ios only */
  onAnnotationToolChanged: {
    tool: number;
  };
  /** ios only */
  onAppShareSplash: Record<string, never>;
  /** android + ios */
  onAppSignalPanelUpdated: {
    inMeetingAppSignalPanelHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  /** ios only */
  onAttendeeAudioStatusNotification: {
    canTalk: boolean;
    isMuted: boolean;
    userId: number;
  };
  /** ios only */
  onAudioOutputChange: Record<string, never>;
  /** ios only */
  onAvailableLanguageListUpdated: {
    availableLanguageListPresent: boolean;
  };
  /** ios only */
  onAvailableSignLanguageListUpdated: {
    availableSignLanguageListPresent: boolean;
  };
  /** android + ios */
  onBOEndTimerUpdated: {
    remaining: number;
    isTimesUpNotice: boolean;
  };
  /** ios only */
  onBOInfoUpdated: {
    boId: string | null;
  };
  /** ios only */
  onBOListInfoUpdated: Record<string, never>;
  /** ios only */
  onBOOptionChanged: {
    newOptionPresent: boolean;
  };
  /** ios only */
  onBOStatusChanged: {
    status: number;
  };
  /** ios only */
  onBOStopCountDown: {
    seconds: number;
  };
  /** ios only */
  onBOSwitchRequestReceived: {
    newBOID: string | null;
    newBOName: string | null;
  };
  /** android + ios */
  onBotAuthorizerRelationChanged: {
    l: number;
    userID: number;
  };
  /** ios only */
  onBroadcastBOVoiceStatus: {
    bStart: boolean;
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
  /** ios only */
  onCaptionStatusChanged: {
    enable: boolean;
  };
  /** android + ios */
  onChatMessageEditNotification: {
    inMeetingChatMessagePresent: boolean;
    chatInfoPresent: boolean;
  };
  /** android only */
  onChatMessageNotification: {
    chatId: string;
    senderId: string;
    senderName: string;
    receiverId: string;
    receiverName: string;
    content: string;
    date: string;
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
    parentVCPresent: boolean;
  };
  /** ios only */
  onClickedDialOut: {
    me: boolean;
    parentVCPresent: boolean;
  };
  /** android + ios */
  onClosedCaptionReceived: {
    message: string | string | null;
    senderId: number;
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
  /** ios only */
  onCreateBOResponse: {
    BOID: string | null;
    success: boolean;
  };
  /** android only */
  onCreateCompanionRelation: {
    l: number;
    l1: number;
  };
  /** ios only */
  onCustomWaitingRoomDataUpdated: {
    dataPresent: boolean;
  };
  /** ios only */
  onDialOutStatusChanged: {
    status: number;
  };
  /** ios only */
  onDisallowPanelistStartVideoNotification: Record<string, never>;
  /** ios only */
  onDocsPermissionChangedCreateOption: {
    createOption: number;
    shareOption: number;
  };
  /** ios only */
  onDocsStatusChanged: {
    sourceInfoPresent: boolean;
  };
  /** ios only */
  onE2EEMeetingSecurityCodeChanged: Record<string, never>;
  /** ios only */
  onEmojiFeedbackCanceled: {
    userId: number;
  };
  /** ios only */
  onEmojiFeedbackReceived: {
    type: number;
    userId: number;
  };
  /** ios only */
  onEmojiReactionReceived: {
    skinTone: number;
    type: number;
    userId: number;
  };
  /** ios only */
  onEmojiReactionReceivedInWebinar: {
    type: number;
  };
  /** ios only */
  onFailedToStartShare: Record<string, never>;
  /** android + ios */
  onFileReceived: {
    zoomSDKFileReceiverPresent: boolean;
    receiverPresent: boolean;
  };
  /** android + ios */
  onFileSendStart: {
    zoomSDKFileSenderPresent: boolean;
    senderPresent: boolean;
  };
  /** android + ios */
  onFileTransferProgress: {
    zoomSDKFileTransferInfoPresent: boolean;
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
  /** android only */
  onFreeMeetingUpgradeToProMeeting: Record<string, never>;
  /** ios only */
  onFreeMeetingUpgradedToProMeeting: Record<string, never>;
  /** ios only */
  onGetRightAnswerListPrivilege: {
    bCan: boolean;
  };
  /** android + ios */
  onGrantCoOwnerPrivilegeChanged: {
    canGrantOther: boolean;
  };
  /** ios only */
  onHasAdminRightsNotification: {
    adminPresent: boolean;
  };
  /** ios only */
  onHasAssistantRightsNotification: {
    assistantPresent: boolean;
  };
  /** ios only */
  onHasAttendeeRightsNotification: {
    attendeePresent: boolean;
  };
  /** ios only */
  onHasCreatorRightsNotification: {
    creatorPresent: boolean;
  };
  /** ios only */
  onHasDataHelperRightsNotification: {
    dataHelperPresent: boolean;
  };
  /** ios only */
  onHelpRequestHandleResultReceived: {
    eResult: number;
  };
  /** android + ios */
  onHelpRequestReceived: {
    strUserID: string | string | null;
  };
  /** ios only */
  onHostInviteReturnToMainSession: {
    hostName: string | null;
    replyHandlerPresent: boolean;
  };
  /** ios only */
  onHostJoinedThisBOMeeting: Record<string, never>;
  /** ios only */
  onHostLeaveThisBOMeeting: Record<string, never>;
  /** ios only */
  onHostUnsupportedStopNotesRequest: Record<string, never>;
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
  /** ios only */
  onIndicatorItemReceived: {
    inMeetingIndicatorHandlerPresent: boolean;
  };
  /** ios only */
  onIndicatorItemRemoved: {
    inMeetingIndicatorHandlerPresent: boolean;
  };
  /** ios only */
  onInterpretationStart: Record<string, never>;
  /** ios only */
  onInterpretationStop: Record<string, never>;
  /** ios only */
  onInterpreterActiveLanguageChanged: {
    activeLanID: number;
    userID: number;
  };
  /** ios only */
  onInterpreterLanguageChanged: {
    lanID1: number;
    lanID2: number;
  };
  /** ios only */
  onInterpreterLanguagesUpdated: {
    availableLanguagesPresent: boolean;
  };
  /** ios only */
  onInterpreterListChanged: Record<string, never>;
  /** ios only */
  onInterpreterRoleChanged: {
    isInterpreter: boolean;
    userID: number;
  };
  /** android only */
  onInvalidReclaimHostkey: Record<string, never>;
  /** ios only */
  onJBHWaitingWithCmd: {
    cmd: number;
  };
  /** ios only */
  onJoinMeetingConfirmed: Record<string, never>;
  /** ios only */
  onJoinMeetingInfoRequired: {
    handlerPresent: boolean;
  };
  /** android + ios */
  onJoinMeetingNeedUserInfo: {
    iMeetingInputUserInfoHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  /** android only */
  onJoinWebinarNeedUserNameAndEmail: {
    handlerPresent: boolean;
  };
  /** ios only */
  onLiveStreamReminderStatusChanged: {
    enable: boolean;
  };
  /** ios only */
  onLiveStreamReminderStatusChangedFailed: Record<string, never>;
  /** ios only */
  onLiveStreamStatusChange: {
    liveStreamStatus: number;
  };
  /** ios only */
  onLiveTranscriptionMsgError: {
    speakLanguagePresent: boolean;
    transcriptLanguagePresent: boolean;
  };
  /** ios only */
  onLiveTranscriptionMsgInfoReceived: {
    messageInfoPresent: boolean;
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
  /** ios only */
  onLostAdminRightsNotification: Record<string, never>;
  /** ios only */
  onLostAssistantRightsNotification: Record<string, never>;
  /** ios only */
  onLostAttendeeRightsNotification: Record<string, never>;
  /** ios only */
  onLostCreatorRightsNotification: Record<string, never>;
  /** ios only */
  onLostDataHelperRightsNotification: Record<string, never>;
  /** android only */
  onLowOrRaiseHandStatusChanged: {
    userId: number;
    isRaisedHand: boolean;
  };
  /** ios only */
  onManualCaptionStatusChanged: {
    bEnabled: boolean;
  };
  /** android only */
  onMeetingActiveVideo: {
    userId: number;
  };
  /** ios only */
  onMeetingCoHostChange: {
    isCoHost: boolean;
    userID: number;
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
  /** ios only */
  onMeetingHostChange: {
    hostId: number;
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
    meetingParamPresent: boolean;
  };
  /** ios only */
  onMeetingQAStatusChanged: {
    isMeetingQAFeatureOn: boolean;
  };
  /** ios only */
  onMeetingReady: Record<string, never>;
  /** ios only */
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
  /** ios only */
  onMyAudioStateChange: Record<string, never>;
  /** ios only */
  onMyVideoStateChange: Record<string, never>;
  /** ios only */
  onNewBroadcastMessageReceived: {
    broadcastMsg: string | null;
    senderID: number;
    senderName: string | null;
  };
  /** ios only */
  onNoHostMeetingWillTerminate: {
    minutes: number;
  };
  /** ios only */
  onNotificationServiceStatus: {
    error: number;
    status: number;
  };
  /** ios only */
  onOngoingShareStopped: Record<string, never>;
  /** ios only */
  onOptimizingShareForVideoClipStatusChanged: {
    shareInfoPresent: boolean;
  };
  /** ios only */
  onOriginalLanguageMsgReceived: {
    messageInfoPresent: boolean;
  };
  /** ios only */
  onPSUserStatusChanged: {
    isStart: boolean;
    userId: number;
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
  /** ios only */
  onPollingActionResult: {
    actionType: number;
    bSuccess: boolean;
    errorMsg: string | null;
    pollingID: string | null;
  };
  /** ios only */
  onPollingElapsedTime: {
    pollingID: string | null;
    uElapsedtime: number;
  };
  /** ios only */
  onPollingInactive: Record<string, never>;
  /** ios only */
  onPollingListUpdated: Record<string, never>;
  /** ios only */
  onPollingQuestionImageDownloaded: {
    path: string | null;
    questionID: string | null;
  };
  /** ios only */
  onPollingResultUpdated: {
    pollingID: string | null;
  };
  /** ios only */
  onPollingStatusChanged: {
    pollingID: string | null;
    status: number;
  };
  /** ios only */
  onRawLiveStreamPrivilegeChanged: {
    hasPrivilege: boolean;
  };
  /** ios only */
  onRawLiveStreamPrivilegeRequestTimeout: Record<string, never>;
  /** ios only */
  onRawLiveStreamPrivilegeRequested: {
    handlerPresent: boolean;
  };
  /** android + ios */
  onRecordingStatus: {
    status: number | string | null;
  };
  /** ios only */
  onRemoveBOResponse: {
    BOID: string | null;
    success: boolean;
  };
  /** android + ios */
  onRemoveCompanionRelation: {
    l: number;
    childUserID: number;
  };
  /** ios only */
  onRequestCloudRecordingResponse: {
    status: number;
  };
  /** android + ios */
  onRequestLocalRecordingPrivilegeChanged: {
    status: number | string | null;
  };
  /** ios only */
  onRequestLocalRecordingPrivilegeReceived: {
    handlerPresent: boolean;
  };
  /** ios only */
  onRequestSignInterpreterToTalk: Record<string, never>;
  /** ios only */
  onSendPairingCodeStateChanged: {
    meetingNumber: number;
    state: number;
  };
  /** ios only */
  onShareContentChanged: {
    shareInfoPresent: boolean;
  };
  /** android + ios */
  onShareFromMainSession: {
    l: number;
    sharingStatus: string | null;
    iShareActionPresent: boolean;
    shareActionPresent: boolean;
    sharingID: number;
    status: number;
  };
  /** android only */
  onShareMeetingChatStatusChanged: {
    start: boolean;
  };
  /** android only */
  onShareSettingTypeChanged: {
    type: string | null;
  };
  /** android only */
  onShareUserReceivingStatus: {
    userId: number;
  };
  /** ios only */
  onSharingContentStartReceiving: Record<string, never>;
  /** ios only */
  onSignInterpretationStatusChange: {
    status: number;
  };
  /** ios only */
  onSignInterpreterLanguageChanged: Record<string, never>;
  /** ios only */
  onSignInterpreterListChanged: Record<string, never>;
  /** ios only */
  onSignInterpreterRoleChanged: Record<string, never>;
  /** android only */
  onSilentModeChanged: {
    inSilentMode: boolean;
  };
  /** android + ios */
  onSinkAllowAttendeeChatNotification: {
    privilege: number;
    currentPrivilege: number;
  };
  /** ios only */
  onSinkAttendeeChatPriviledgeChanged: {
    currentPrivilege: number;
  };
  /** android only */
  onSinkAttendeeChatPrivilegeChanged: {
    i: number;
  };
  /** ios only */
  onSinkAttendeePromoteConfirmResult: {
    agree: boolean;
    userId: number;
  };
  /** ios only */
  onSinkDePromptPanelist2AttendeeResult: {
    errorCode: number;
  };
  /** ios only */
  onSinkDeleteAnswer: {
    answerIDArray: string[];
  };
  /** ios only */
  onSinkDeleteQuestion: {
    questionIDArray: string[];
  };
  /** android + ios */
  onSinkJoin3rdPartyTelephonyAudio: {
    s: string;
    audioInfo: string | null;
  };
  /** ios only */
  onSinkLiveTranscriptionStatus: {
    status: number;
  };
  /** ios only */
  onSinkLowerAllHands: Record<string, never>;
  /** ios only */
  onSinkMeetingActiveVideo: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingAudioRequestUnmuteByHost: Record<string, never>;
  /** ios only */
  onSinkMeetingAudioStatusChange: {
    audioStatus: number;
    userID: number;
  };
  /** ios only */
  onSinkMeetingAudioTypeChange: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingMyAudioTypeChange: Record<string, never>;
  /** ios only */
  onSinkMeetingPreviewStopped: Record<string, never>;
  /** ios only */
  onSinkMeetingShowMinimizeMeetingOrBackZoomUI: {
    state: number;
  };
  /** ios only */
  onSinkMeetingUserJoin: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingUserLeft: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingUserLowerHand: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingUserRaiseHand: {
    userID: number;
  };
  /** ios only */
  onSinkMeetingVideoQualityChanged: {
    qality: number;
    userID: number;
  };
  /** ios only */
  onSinkMeetingVideoRequestUnmuteByHost: Record<string, never>;
  /** ios only */
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
  /** ios only */
  onSinkPromptAttendee2PanelistResult: {
    errorCode: number;
  };
  /** ios only */
  onSinkQAAddAnswer: {
    answerID: string | null;
    success: boolean;
  };
  /** ios only */
  onSinkQAAddQuestion: {
    questionID: string | null;
    success: boolean;
  };
  /** ios only */
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
  /** ios only */
  onSinkQAAllowAttendeeViewAllQuestionNotification: {
    beAllowed: boolean;
  };
  /** ios only */
  onSinkQAConnectStarted: Record<string, never>;
  /** ios only */
  onSinkQAConnected: {
    connected: boolean;
  };
  /** ios only */
  onSinkQAOpenQuestionChanged: {
    count: number;
  };
  /** ios only */
  onSinkQuestionMarkedAsDismissed: {
    questionID: string | null;
  };
  /** ios only */
  onSinkReceiveAnswer: {
    answerID: string | null;
  };
  /** ios only */
  onSinkReceiveQuestion: {
    questionID: string | null;
  };
  /** ios only */
  onSinkReopenQuestion: {
    questionID: string | null;
  };
  /** ios only */
  onSinkRequestForLiveTranscriptReceived: {
    bAnonymous: boolean;
    requesterUserId: number;
  };
  /** ios only */
  onSinkRevokeVoteupQuestion: {
    orderChanged: boolean;
    questionID: string | null;
  };
  /** ios only */
  onSinkSelfAllowTalkNotification: Record<string, never>;
  /** ios only */
  onSinkSelfDisallowTalkNotification: Record<string, never>;
  /** ios only */
  onSinkShareSettingTypeChanged: {
    shareSettingType: number;
  };
  /** ios only */
  onSinkShareSizeChange: {
    userID: number;
  };
  /** ios only */
  onSinkSharingStatus: {
    shareInfoPresent: boolean;
  };
  /** ios only */
  onSinkUserEndLiving: {
    questionID: string | null;
  };
  /** ios only */
  onSinkUserLivingReply: {
    questionID: string | null;
  };
  /** ios only */
  onSinkUserNameChanged: {
    userNameChangedArr: number[];
  };
  /** ios only */
  onSinkVoteupQuestion: {
    orderChanged: boolean;
    questionID: string | null;
  };
  /** ios only */
  onSinkWebinarNeedRegister: {
    registerURL: string | null;
  };
  /** ios only */
  onSpokenLanguageChanged: {
    spokenLanguagePresent: boolean;
  };
  /** ios only */
  onSpotlightVideoChange: {
    on: boolean;
  };
  /** android only */
  onSpotlightVideoChanged: {
    userList: number[];
  };
  /** ios only */
  onSpotlightVideoUserChange: {
    spotlightedUserList: number[];
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
  /** ios only */
  onStartCaptionsRequestApproved: Record<string, never>;
  /** ios only */
  onStartCaptionsRequestReceived: {
    handlerPresent: boolean;
  };
  /** ios only */
  onStartCloudRecordingRequested: {
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
  /** ios only */
  onTalkPrivilegeChanged: {
    hasPrivilege: boolean;
  };
  /** android + ios */
  onUVCCameraStatusChange: {
    cameraId: string;
    status: number | string | null;
  };
  /** ios only */
  onUnAssignedUserUpdated: Record<string, never>;
  /** ios only */
  onUpdateBONameResponse: {
    BOID: string | null;
    success: boolean;
  };
  /** ios only */
  onUpgradeFreeMeetingResult: {
    result: number;
  };
  /** android only */
  onUserAudioTypeChanged: {
    userId: number;
  };
  /** android + ios */
  onUserConfirmRecoverMeeting: {
    iRecoverMeetingHandlePresent: boolean;
    handlerPresent: boolean;
  };
  /** android + ios */
  onUserConfirmToStartArchive: {
    iMeetingArchiveConfirmHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  /** android only */
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
  /** ios only */
  onUserRawLiveStreamPrivilegeChanged: {
    hasPrivilege: number;
    userId: number;
  };
  /** ios only */
  onUserRawLiveStreamingStatusChanged: {
    liveStreamListPresent: boolean;
  };
  /** ios only */
  onUserThresholdReachedForLiveStream: {
    percent: number;
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
  /** ios only */
  onWaitingRoomEntranceEnabled: {
    enabled: boolean;
  };
  /** ios only */
  onWaitingRoomPresetAudioStatusChanged: {
    audioCanTurnOn: boolean;
  };
  /** ios only */
  onWaitingRoomPresetVideoStatusChanged: {
    videoCanTurnOn: boolean;
  };
  /** ios only */
  onWaitingRoomStatusChange: {
    needWaiting: boolean;
  };
  /** ios only */
  onWaitingRoomUserJoin: {
    userId: number;
  };
  /** ios only */
  onWaitingRoomUserLeft: {
    userId: number;
  };
  /** ios only */
  onWaitingRoomUserNameChanged: {
    userID: number;
    userName: string | null;
  };
  /** ios only */
  onWebPreAssignBODataDownloadStatusChanged: {
    status: number;
  };
  /** android + ios */
  onWebinarNeedInputScreenName: {
    inMeetingEventHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  /** android only */
  onWebinarNeedRegister: {
    registerUrl: string;
  };
  /** ios only */
  onWhiteboardSettingsChanged: {
    createOption: number;
    enable: boolean;
    shareOption: number;
  };
  /** ios only */
  onWhiteboardStatusChanged: {
    status: number;
  };
  /** android only */
  onZoomAuthIdentityExpired: Record<string, never>;
  /** ios only */
  onZoomIdentityExpired: Record<string, never>;
  /** android only */
  screenShareError: Record<string, never>;
  /** android only */
  screenShareStarted: Record<string, never>;
  /** android only */
  screenShareStopped: Record<string, never>;
  /** android only */
  screenShareSuccess: Record<string, never>;
  /** android only */
  userJoin: {
    userList: number[];
  };
  /** android only */
  userLeave: {
    userList: number[];
  };
}

export type ZoomEventName = keyof ZoomEventPayloads;

/** Payload as delivered on the wire: the event name travels with it. */
export type ZoomEvent<K extends ZoomEventName = ZoomEventName> = {
  [E in K]: ZoomEventPayloads[E] & { event: E; channel?: string };
}[K];
