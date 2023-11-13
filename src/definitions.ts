import { PluginListenerHandle } from '@capacitor/core';

export enum SpeechToTextListeners {
  textRecognition, notifyStatus, notifyError, soundLevelChange
}

export enum SpeechToTextStatus {
  listening, notListening, unavaialble, available, done, doneNoResult
}

export enum SpeechToTextErrors {
  onDeviceError, noRecognizerError, listenFailedError, missingOrInvalidArg
}

export enum ListenMode {
  devcieDefault, dictation, search, confirmation
}

export interface SpeechRecognitionWords {
  recogizedWrods: string;
  confidence: number;
}

export interface SpeechRecognitionResult {
  alternates: SpeechRecognitionWords[];
  finalResult: boolean;
}

export interface SpeechRecognitionError {
  errorMsg: string;
  permanent: boolean
}

export interface SpeechParams {
  onDevice: boolean;
  partialResults: boolean;
  sampleRate: number;
  listenMode: ListenMode;
  localeStr?: string;
}

export interface SpeechToTextPlugin {

  hasPermission(): Promise<{ permission: boolean }>;
  initialize(): Promise<{ available: boolean }>;
  locales(): Promise<{ languages: any[] }>;
  stop(): Promise<{ stopped: boolean }>;
  cancel(): Promise<{ cancelled: boolean }>;
  listen(options: SpeechParams): Promise<{ listening: boolean }>;

  /**
   * Called on textRecognition and result received
   *
   * Provides textRecognition result.
   *
   * @since 0.0.1
   */
  addListener(
    eventName: "textRecognition",
    listenerFunc: (data: { speechString: string }) => void,
  ): Promise<PluginListenerHandle> & PluginListenerHandle;
  /**
   * Called when status changes and result received
   *
   * Provides speech recognition status.
   *
   * @since 0.0.1
   */

  addListener(
    eventName: "notifyStatus",
    listenerFunc: (data: { status: string }) => void,
  ): Promise<PluginListenerHandle> & PluginListenerHandle;

  /**
   * Called when there is an error and result received
   *
   * Provides speech recognition error.
   *
   * @since 0.0.1
   */
  addListener(
    eventName: "notifyError",
    listenerFunc: (data: { error: string }) => void,
  ): Promise<PluginListenerHandle> & PluginListenerHandle;

  /**
   * Called when sound level changes and result received
   *
   * Provides sound level change.
   *
   * @since 0.0.1
   */
  addListener(
    eventName: "soundLevelChange",
    listenerFunc: (data: { soundLevel: string }) => void,
  ): Promise<PluginListenerHandle> & PluginListenerHandle;
}

