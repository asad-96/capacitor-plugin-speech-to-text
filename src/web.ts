import { WebPlugin } from '@capacitor/core';

import type { SpeechParams, SpeechToTextPlugin } from './definitions';

export class SpeechToTextWeb extends WebPlugin implements SpeechToTextPlugin {
  hasPermission(): Promise<{ permission: boolean; }> {
    throw new Error('Method not implemented.');
  }
  initialize(): Promise<{ available: boolean; }> {
    throw new Error('Method not implemented.');
  }
  locales(): Promise<{ languages: any[]; }> {
    throw new Error('Method not implemented.');
  }
  stop(): Promise<{ stopped: boolean }> {
    throw new Error('Method not implemented.');
  }
  cancel(): Promise<{ cancelled: boolean }> {
    throw new Error('Method not implemented.');
  }
  listen(options: SpeechParams): Promise<{ listening: boolean; }> {
    throw new Error(`Method not implemented. ${options}`);
  }
}
