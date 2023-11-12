import { WebPlugin } from '@capacitor/core';

import type { SpeechToTextPlugin } from './definitions';

export class SpeechToTextWeb extends WebPlugin implements SpeechToTextPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
