// AUTO-GENERATED from the native emitters on both platforms:
//   android/src/main/java/ch/milosz/reactnative/RNZoomUsModule.java
//   src/events/ios-events.json (written by scripts/generate-ios-delegates.py)
// Regenerate with scripts/generate-events.py. Do not edit by hand.
// 42 Android-only, 187 iOS-only, 56 on both.

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
  askUnMuteAudio: Record<string, never>;
  askUnMuteVideo: Record<string, never>;
  coHostChanged: {
    userId: number;
  };
  hostChanged: {
    userId: number;
  };
  inMeetingUserCount: {
    userList: number;
  };
  myAudioSourceTypeChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  myAudioStatusChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  myVideoStatusChanged: {
    userRole: string;
    audioType: number;
    isTalking: boolean;
    isMutedAudio: boolean;
    isMutedVideo: boolean;
  };
  on3DAvatarItemDataDownloaded: {
    success: number;
    index: number;
  };
  on3DAvatarItemDataDownloading: {
    index: number;
  };
  on3DAvatarItemThumbnailsDownloaded: Record<string, never>;
  onAICompanionActiveChangeNotice: {
    b: boolean;
    isActive: boolean;
  };
  onAICompanionFeatureCanNotBeTurnedOff: {
    featuresArr: number[];
  };
  onAICompanionFeatureSwitchRequestResponse: {
    timeout: boolean;
    agree: boolean;
    turnOn: boolean;
  };
  onAICompanionFeatureSwitchRequested: {
    handlerPresent: boolean;
  };
  onAICompanionFeatureTurnOffByParticipant: {
    handlerPresent: boolean;
  };
  onActiveSpeakerVideoUserChanged: {
    userId: number;
    userID: number;
  };
  onActiveVideoUserChanged: {
    userId: number;
  };
  onAllHandsLowered: Record<string, never>;
  onAllowAskQuestionStatus: {
    bEnabled: boolean;
  };
  onAllowAttendeeRaiseHandStatusChanged: {
    canRaiseHand: boolean;
  };
  onAllowAttendeeViewTheParticipantCountStatusChanged: {
    canViewParticipantCount: boolean;
  };
  onAllowParticipantsRenameNotification: {
    allow: boolean;
  };
  onAllowParticipantsRequestCloudRecording: {
    bAllow: boolean;
    allow: boolean;
  };
  onAllowParticipantsShareStatusNotification: {
    allow: boolean;
  };
  onAllowParticipantsShareWhiteBoardNotification: {
    allow: boolean;
  };
  onAllowParticipantsStartVideoNotification: {
    allow: boolean;
  };
  onAllowParticipantsUnmuteSelfNotification: {
    allow: boolean;
  };
  onAllowWebinarReactionStatusChanged: {
    canReaction: boolean;
  };
  onAppShareSplash: Record<string, never>;
  onAppSignalPanelUpdated: {
    inMeetingAppSignalPanelHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  onAudioOutputChange: Record<string, never>;
  onAvailableLanguageListUpdated: {
    availableLanguageListPresent: boolean;
  };
  onAvailableSignLanguageListUpdated: {
    availableSignLanguageListPresent: boolean;
  };
  onBOCreateSuccess: {
    BOID: string | null;
  };
  onBOEndTimerUpdated: {
    remaining: number;
    isTimesUpNotice: boolean;
  };
  onBOInfoUpdated: {
    boId: string | null;
  };
  onBOListInfoUpdated: Record<string, never>;
  onBOOptionChanged: {
    newOptionPresent: boolean;
  };
  onBOStatusChanged: {
    status: number;
  };
  onBOStopCountDown: {
    seconds: number;
  };
  onBOSwitchRequestReceived: {
    newBOName: string | null;
    newBOID: string | null;
  };
  onBotAuthorizerRelationChanged: {
    l: number;
    userID: number;
  };
  onBroadcastBOVoiceStatus: {
    bStart: boolean;
  };
  onCallRoomDeviceStateChanged: {
    state: number;
  };
  onCameraControlRequestReceived: {
    l: number;
    cameraControlRequestType: string | null;
    iCameraControlRequestHandlerPresent: boolean;
  };
  onCameraControlRequestResult: {
    l: number;
    cameraControlRequestResult: string | null;
  };
  onCameraNoPrivilege: Record<string, never>;
  onCaptionStatusChanged: {
    enable: boolean;
  };
  onChatMessageEditNotification: {
    inMeetingChatMessagePresent: boolean;
    chatInfoPresent: boolean;
  };
  onChatMessageNotification: {
    chatId: string;
    senderId: string;
    senderName: string;
    receiverId: string;
    receiverName: string;
    content: string;
    date: string;
    chatInfoPresent: boolean;
  };
  onChatMsgDeleteNotification: {
    msgID: string | null;
    deleteBy: number;
  };
  onCheckCMRPrivilege: {
    result: number;
  };
  onClaimHostResult: {
    error: number;
  };
  onClickShareScreen: {
    parentVCPresent: boolean;
  };
  onClickedDialOut: {
    parentVCPresent: boolean;
    me: boolean;
  };
  onClosedCaptionReceived: {
    message: string | string | null;
    senderId: number;
    speakerID: number;
    msgTimePresent: boolean;
  };
  onCloudRecordingStorageFull: {
    l: number;
    gracePeriodDate: number;
  };
  onCompanionRelationChangedParentUserID: {
    parentUserID: number;
    childUserID: number;
  };
  onCreateBOResponse: {
    success: boolean;
    BOID: string | null;
  };
  onCreateCompanionRelation: {
    l: number;
    l1: number;
  };
  onDialOutStatusChanged: {
    status: number;
  };
  onDocsPermissionChangedCreateOption: {
    createOption: number;
    shareOption: number;
  };
  onDocsStatusChanged: {
    sourceInfoPresent: boolean;
  };
  onE2EEMeetingSecurityCodeChanged: Record<string, never>;
  onEmojiFeedbackCanceled: {
    userId: number;
  };
  onEmojiFeedbackReceived: {
    userId: number;
    type: number;
  };
  onEmojiReactionReceived: {
    userId: number;
    type: number;
    skinTone: number;
  };
  onEmojiReactionReceivedInWebinar: {
    type: number;
  };
  onFailedToStartShare: Record<string, never>;
  onFileReceived: {
    zoomSDKFileReceiverPresent: boolean;
    receiverPresent: boolean;
  };
  onFileSendStart: {
    zoomSDKFileSenderPresent: boolean;
    senderPresent: boolean;
  };
  onFileTransferProgress: {
    zoomSDKFileTransferInfoPresent: boolean;
    infoPresent: boolean;
  };
  onFocusModeShareTypeChanged: {
    shareType: number | string | null;
  };
  onFocusModeStateChanged: {
    on: boolean;
  };
  onFollowHostVideoOrderChanged: {
    bFollow: boolean;
    follow: boolean;
  };
  onFreeMeetingNeedToUpgrade: {
    type: number | string | null;
    gifUrl: string;
    giftURL: string | null;
  };
  onFreeMeetingReminder: {
    isHost: boolean;
    canUpgrade: boolean;
    isFirstGift: boolean;
  };
  onFreeMeetingUpgradeToGiftFreeTrialStart: Record<string, never>;
  onFreeMeetingUpgradeToGiftFreeTrialStop: Record<string, never>;
  onFreeMeetingUpgradeToProMeeting: Record<string, never>;
  onFreeMeetingUpgradedToProMeeting: Record<string, never>;
  onGetRightAnswerListPrivilege: {
    bCan: boolean;
  };
  onGrantCoOwnerPrivilegeChanged: {
    canGrantOther: boolean;
  };
  onHasAdminRightsNotification: {
    adminPresent: boolean;
  };
  onHasAssistantRightsNotification: {
    assistantPresent: boolean;
  };
  onHasAttendeeRightsNotification: {
    attendeePresent: boolean;
  };
  onHasCreatorRightsNotification: {
    creatorPresent: boolean;
  };
  onHasDataHelperRightsNotification: {
    dataHelperPresent: boolean;
  };
  onHelpRequestHandleResultReceived: {
    eResult: number;
  };
  onHelpRequestReceived: {
    strUserID: string | string | null;
  };
  onHostInviteReturnToMainSession: {
    hostName: string | null;
    replyHandlerPresent: boolean;
  };
  onHostJoinedThisBOMeeting: Record<string, never>;
  onHostLeaveThisBOMeeting: Record<string, never>;
  onHostUnsupportedStopNotesRequest: Record<string, never>;
  onHostVideoOrderUpdated: {
    orderList: number[];
    orderArr: number[];
  };
  onInMeetingUserAvatarPathUpdated: {
    userId: number;
    userID: number;
  };
  onInMeetingUserUpdated: Record<string, never>;
  onIndicatorItemReceived: {
    inMeetingIndicatorHandlerPresent: boolean;
  };
  onIndicatorItemRemoved: {
    inMeetingIndicatorHandlerPresent: boolean;
  };
  onInterpretationStart: Record<string, never>;
  onInterpretationStop: Record<string, never>;
  onInterpreterActiveLanguageChanged: {
    userID: number;
    activeLanID: number;
  };
  onInterpreterLanguageChanged: {
    lanID1: number;
    lanID2: number;
  };
  onInterpreterLanguagesUpdated: {
    availableLanguagesPresent: boolean;
  };
  onInterpreterListChanged: Record<string, never>;
  onInterpreterRoleChanged: {
    userID: number;
    isInterpreter: boolean;
  };
  onInvalidReclaimHostkey: Record<string, never>;
  onJBHWaitingWithCmd: {
    cmd: number;
  };
  onJoinMeetingConfirmed: Record<string, never>;
  onJoinMeetingInfoRequired: {
    handlerPresent: boolean;
  };
  onJoinMeetingNeedUserInfo: {
    iMeetingInputUserInfoHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  onJoinWebinarNeedUserNameAndEmail: {
    handlerPresent: boolean;
  };
  onLiveStreamReminderStatusChanged: {
    enable: boolean;
  };
  onLiveStreamReminderStatusChangedFailed: Record<string, never>;
  onLiveStreamStatusChange: {
    liveStreamStatus: number;
  };
  onLiveTranscriptionMsgError: {
    speakLanguagePresent: boolean;
    transcriptLanguagePresent: boolean;
  };
  onLiveTranscriptionMsgInfoReceived: {
    messageInfoPresent: boolean;
  };
  onLocalRecordingPrivilegeRequested: {
    handlerPresent: boolean;
  };
  onLocalRecordingStatus: {
    userId: number;
    recordingStatus: string | null;
    status: number;
  };
  onLocalVideoOrderUpdated: {
    localOrderList: number[];
    localOrderArr: number[];
  };
  onLostAdminRightsNotification: Record<string, never>;
  onLostAssistantRightsNotification: Record<string, never>;
  onLostAttendeeRightsNotification: Record<string, never>;
  onLostCreatorRightsNotification: Record<string, never>;
  onLostDataHelperRightsNotification: Record<string, never>;
  onLowOrRaiseHandStatusChanged: {
    userId: number;
    isRaisedHand: boolean;
  };
  onManualCaptionStatusChanged: {
    bEnabled: boolean;
  };
  onMeetingActiveVideo: {
    userId: number;
  };
  onMeetingCoHostChange: {
    userID: number;
    isCoHost: boolean;
  };
  onMeetingEndedReason: {
    reason: number;
  };
  onMeetingError: {
    error: number;
    message: string | null;
  };
  onMeetingFail: {
    errorCode: number;
    internalErrorCode: number;
  };
  onMeetingFullToWatchLiveStream: {
    s: string;
    liveStreamUrl: string | null;
  };
  onMeetingHostChange: {
    hostId: number;
  };
  onMeetingLockStatus: {
    isLock: boolean;
  };
  onMeetingNeedCloseOtherMeeting: {
    handlerPresent: boolean;
  };
  onMeetingNeedConfirmPreview: {
    inMeetingPreviewHandlerPresent: boolean;
  };
  onMeetingNeedPasswordOrDisplayName: {
    needPassword: boolean;
    needDisplayName: boolean;
    handlerPresent: boolean;
  };
  onMeetingParameterNotification: {
    meetingParameter: ZoomMeetingParameter | null;
    meetingParamPresent: boolean;
  };
  onMeetingQAStatusChanged: {
    isMeetingQAFeatureOn: boolean;
  };
  onMeetingReady: Record<string, never>;
  onMeetingStateChange: {
    state: number;
  };
  onMeetingTopicChanged: {
    s: string;
    meetingTopic: string | null;
  };
  onMeetingUserUpdated: {
    userId: number;
  };
  onMicrophoneNoPrivilege: Record<string, never>;
  onMicrophoneStatusError: {
    error: number | string | null;
  };
  onMuteOnEntryStatusChange: {
    b: boolean;
    bEnabled: boolean;
  };
  onMyAudioStateChange: Record<string, never>;
  onMyHandStateChange: Record<string, never>;
  onMyVideoStateChange: Record<string, never>;
  onNewBroadcastMessageReceived: {
    broadcastMsg: string | null;
    senderID: number;
    senderName: string | null;
  };
  onNoHostMeetingWillTerminate: {
    minutes: number;
  };
  onOngoingShareStopped: Record<string, never>;
  onOptimizingShareForVideoClipStatusChanged: {
    shareInfoPresent: boolean;
  };
  onOriginalLanguageMsgReceived: {
    messageInfoPresent: boolean;
  };
  onPSUserStatusChanged: {
    userId: number;
    isStart: boolean;
  };
  onParticipantProfilePictureStatusChange: {
    b: boolean;
    hidden: boolean;
  };
  onPermissionRequested: {
    permissions: string[];
  };
  onPollingActionResult: {
    actionType: number;
    pollingID: string | null;
    bSuccess: boolean;
    errorMsg: string | null;
  };
  onPollingElapsedTime: {
    pollingID: string | null;
    uElapsedtime: number;
  };
  onPollingInactive: Record<string, never>;
  onPollingListUpdated: Record<string, never>;
  onPollingQuestionImageDownloaded: {
    questionID: string | null;
    path: string | null;
  };
  onPollingResultUpdated: {
    pollingID: string | null;
  };
  onPollingStatusChanged: {
    pollingID: string | null;
    status: number;
  };
  onRawLiveStreamPrivilegeChanged: {
    hasPrivilege: boolean;
  };
  onRawLiveStreamPrivilegeRequestTimeout: Record<string, never>;
  onRawLiveStreamPrivilegeRequested: {
    handlerPresent: boolean;
  };
  onRecordingStatus: {
    status: number | string | null;
  };
  onRemoveBOResponse: {
    success: boolean;
    BOID: string | null;
  };
  onRemoveCompanionRelation: {
    l: number;
    childUserID: number;
  };
  onRequestCloudRecordingResponse: {
    status: number;
  };
  onRequestLocalRecordingPrivilegeChanged: {
    status: number | string | null;
  };
  onRequestLocalRecordingPrivilegeReceived: {
    handlerPresent: boolean;
  };
  onRequestSignInterpreterToTalk: Record<string, never>;
  onSendPairingCodeStateChanged: {
    state: number;
    meetingNumber: number;
  };
  onShareContentChanged: {
    shareInfoPresent: boolean;
  };
  onShareFromMainSession: {
    l: number;
    sharingStatus: string | null;
    iShareActionPresent: boolean;
    sharingID: number;
    status: number;
    shareActionPresent: boolean;
  };
  onShareMeetingChatStatusChanged: {
    start: boolean;
  };
  onShareSettingTypeChanged: {
    type: string | null;
  };
  onShareUserReceivingStatus: {
    userId: number;
  };
  onSignInterpretationStatusChange: {
    status: number;
  };
  onSignInterpreterLanguageChanged: Record<string, never>;
  onSignInterpreterListChanged: Record<string, never>;
  onSignInterpreterRoleChanged: Record<string, never>;
  onSilentModeChanged: {
    inSilentMode: boolean;
  };
  onSinkAllowAttendeeChatNotification: {
    privilege: number;
    currentPrivilege: number;
  };
  onSinkAttendeeChatPriviledgeChanged: {
    currentPrivilege: number;
  };
  onSinkAttendeeChatPrivilegeChanged: {
    i: number;
  };
  onSinkAttendeePromoteConfirmResult: {
    agree: boolean;
    userId: number;
  };
  onSinkDePromptPanelist2AttendeeResult: {
    errorCode: number;
  };
  onSinkDeleteAnswer: {
    answerIDArray: string[];
  };
  onSinkDeleteQuestion: {
    questionIDArray: string[];
  };
  onSinkJoin3rdPartyTelephonyAudio: {
    s: string;
    audioInfo: string | null;
  };
  onSinkLiveTranscriptionStatus: {
    status: number;
  };
  onSinkLowerAllHands: Record<string, never>;
  onSinkMeetingActiveVideo: {
    userID: number;
  };
  onSinkMeetingActiveVideoForDeck: {
    userID: number;
  };
  onSinkMeetingAudioRequestUnmuteByHost: Record<string, never>;
  onSinkMeetingAudioStatusChange: {
    userID: number;
  };
  onSinkMeetingAudioTypeChange: {
    userID: number;
  };
  onSinkMeetingMyAudioTypeChange: Record<string, never>;
  onSinkMeetingPreviewStopped: Record<string, never>;
  onSinkMeetingShowMinimizeMeetingOrBackZoomUI: {
    state: number;
  };
  onSinkMeetingUserJoin: {
    userID: number;
  };
  onSinkMeetingUserLeft: {
    userID: number;
  };
  onSinkMeetingUserLowerHand: {
    userID: number;
  };
  onSinkMeetingUserRaiseHand: {
    userID: number;
  };
  onSinkMeetingVideoQualityChanged: {
    videoQuality: string | null;
    userId: number;
    qality: number;
    userID: number;
  };
  onSinkMeetingVideoStatusChange: {
    userID: number;
    videoStatus: number;
  };
  onSinkPanelistCapacityExceed: Record<string, never>;
  onSinkPanelistChatPrivilegeChanged: {
    privilege: number | string | null;
  };
  onSinkPromptAttendee2PanelistResult: {
    errorCode: number;
  };
  onSinkQAAddAnswer: {
    answerID: string | null;
    success: boolean;
  };
  onSinkQAAddQuestion: {
    questionID: string | null;
    success: boolean;
  };
  onSinkQAAllowAskQuestionAnonymouslyNotification: {
    beAllowed: boolean;
  };
  onSinkQAAllowAttendeeAnswerQuestionNotification: {
    beAllowed: boolean;
  };
  onSinkQAAllowAttendeeUpVoteQuestionNotification: {
    beAllowed: boolean;
  };
  onSinkQAAllowAttendeeViewAllQuestionNotification: {
    beAllowed: boolean;
  };
  onSinkQAConnectStarted: Record<string, never>;
  onSinkQAConnected: {
    connected: boolean;
  };
  onSinkQAOpenQuestionChanged: {
    count: number;
  };
  onSinkQuestionMarkedAsDismissed: {
    questionID: string | null;
  };
  onSinkReceiveAnswer: {
    answerID: string | null;
  };
  onSinkReceiveQuestion: {
    questionID: string | null;
  };
  onSinkReopenQuestion: {
    questionID: string | null;
  };
  onSinkRequestForLiveTranscriptReceived: {
    requesterUserId: number;
    bAnonymous: boolean;
  };
  onSinkRevokeVoteupQuestion: {
    questionID: string | null;
    orderChanged: boolean;
  };
  onSinkSelfAllowTalkNotification: Record<string, never>;
  onSinkSelfDisallowTalkNotification: Record<string, never>;
  onSinkShareSettingTypeChanged: {
    shareSettingType: number;
  };
  onSinkShareSizeChange: {
    userID: number;
  };
  onSinkSharingStatus: {
    shareInfoPresent: boolean;
  };
  onSinkUserEndLiving: {
    questionID: string | null;
  };
  onSinkUserLivingReply: {
    questionID: string | null;
  };
  onSinkUserNameChanged: {
    userNameChangedArr: number[];
  };
  onSinkVoteupQuestion: {
    questionID: string | null;
    orderChanged: boolean;
  };
  onSinkWebinarNeedRegister: {
    registerURL: string | null;
  };
  onSmartSummaryPrivilegeRequested: {
    userId: number;
    handlerPresent: boolean;
  };
  onSmartSummaryStartReqResponse: {
    timeout: boolean;
    isDecline: boolean;
  };
  onSmartSummaryStatusChange: {
    isStarted: boolean;
  };
  onSpokenLanguageChanged: {
    spokenLanguagePresent: boolean;
  };
  onSpotlightVideoChange: {
    on: boolean;
  };
  onSpotlightVideoChanged: {
    userList: number[];
  };
  onSpotlightVideoUserChange: {
    spotlightedUserList: number[];
  };
  onStartBOError: {
    errType: number;
  };
  onStartBOResponse: {
    bSuccess: boolean;
    success: boolean;
  };
  onStartCaptionsRequestApproved: Record<string, never>;
  onStartCaptionsRequestReceived: {
    handlerPresent: boolean;
  };
  onStartCloudRecordingRequested: {
    handlerPresent: boolean;
  };
  onStopBOResponse: {
    bSuccess: boolean;
    success: boolean;
  };
  onSubscribeUserFail: {
    errorCode: number;
    size: number;
    userId: number;
  };
  onSuspendParticipantsActivities: Record<string, never>;
  onTalkPrivilegeChanged: {
    hasPrivilege: boolean;
  };
  onUVCCameraStatusChange: {
    cameraId: string;
    status: number | string | null;
  };
  onUnAssignedUserUpdated: Record<string, never>;
  onUpdateBONameResponse: {
    success: boolean;
    BOID: string | null;
  };
  onUpgradeFreeMeetingResult: {
    result: number;
  };
  onUserAudioTypeChanged: {
    userId: number;
  };
  onUserConfirmRecoverMeeting: {
    iRecoverMeetingHandlePresent: boolean;
    handlerPresent: boolean;
  };
  onUserConfirmToStartArchive: {
    iMeetingArchiveConfirmHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  onUserNamesChanged: {
    userList: number[];
  };
  onUserNetworkStatusChanged: {
    componentType: string | null;
    quality: string | null;
    userId: number;
    isMyself: boolean;
    type: number;
    level: number;
    userID: number;
    uplink: boolean;
  };
  onUserRawLiveStreamPrivilegeChanged: {
    userId: number;
    hasPrivilege: number;
  };
  onUserRawLiveStreamingStatusChanged: {
    liveStreamListPresent: boolean;
  };
  onUserThresholdReachedForLiveStream: {
    percent: number;
  };
  onVideoAlphaChannelStatusChanged: {
    isAlphaModeOn: boolean;
    alphaChannelOn: boolean;
  };
  onVirtualNameTagRosterInfoUpdated: {
    l: number;
    userID: number;
  };
  onVirtualNameTagStatusChanged: {
    b: boolean;
    l: number;
    bOn: boolean;
    userID: number;
  };
  onWaitingRoomEntranceEnabled: {
    enabled: boolean;
  };
  onWaitingRoomStatusChange: {
    needWaiting: boolean;
  };
  onWebPreAssignBODataDownloadStatusChanged: {
    status: number;
  };
  onWebinarNeedInputScreenName: {
    inMeetingEventHandlerPresent: boolean;
    handlerPresent: boolean;
  };
  onWebinarNeedRegister: {
    registerUrl: string;
  };
  onWhiteboardSettingsChanged: {
    shareOption: number;
    createOption: number;
    enable: boolean;
  };
  onWhiteboardStatusChanged: {
    status: number;
  };
  onZoomAuthIdentityExpired: Record<string, never>;
  onZoomIdentityExpired: Record<string, never>;
  screenShareError: Record<string, never>;
  screenShareStarted: Record<string, never>;
  screenShareStopped: Record<string, never>;
  screenShareSuccess: Record<string, never>;
  userJoin: {
    userList: number[];
  };
  userLeave: {
    userList: number[];
  };
}

export type ZoomEventName = keyof ZoomEventPayloads;

/** Payload as delivered on the wire: the event name travels with it. */
export type ZoomEvent<K extends ZoomEventName = ZoomEventName> = {
  [E in K]: ZoomEventPayloads[E] & { event: E; channel?: string };
}[K];
