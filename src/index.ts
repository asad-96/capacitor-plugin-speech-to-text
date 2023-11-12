import { registerPlugin } from '@capacitor/core';

import type { SpeechToTextPlugin } from './definitions';

const SpeechToText = registerPlugin<SpeechToTextPlugin>('SpeechToText', {
  web: () => import('./web').then(m => new m.SpeechToTextWeb()),
});

export * from './definitions';
export { SpeechToText };
