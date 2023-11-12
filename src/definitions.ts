export interface SpeechToTextPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
