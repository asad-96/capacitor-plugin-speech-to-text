import EventBus from 'eventing-bus';
import util from './util';
import { Capacitor } from '@capacitor/core';
import { ListenMode, SpeechToText } from "capacitor-plugin-speech-to-text";

// When we're not detecting any speech, need to allow time in case the user
// is just pausing briefly. After this many ms, we assume the person is done
// talking, speech transcription is final and we can send it to our AI model.
const MS_OF_SILENCE_TO_ALLOW_BEFORE_PROCESSING = 150;

/**
 * Interface: audio-capture.listen()
 */
export default {

    listening: false,               // Speech recognition in active use now?
    final_transcript: '',           // Transcript of the speech heard so far
    started_listening_at: null,     // Epoch ms when we started listening.
    recognition_engine: null,


    // Listens for user input, calls the callback function when it senses the user is done speaking.
    listen() {
        // Already listening? Ignore this call.
        if (this.listening) return;

        this.final_transcript = '';
    
        // Hello! This is where we need to check for the iOS platform and start the ios recognizer.
        try {

            // this.startHtml5Recognizer();

            if (Capacitor.getPlatform() == 'ios') {
                this.startIosRecognizer();
            } else {
                this.startHtml5Recognizer();
            }
        } catch (err) {
            // Already running - ok to ignore.
        }
    },

    stop() {
        if (this.listening) {
            this.recognition_engine.stop();
            this.listening = false;
            this.final_transcript = '';
        }
    },

    init() {
        if (Capacitor.getPlatform() == 'ios') {
            console.log(`locales`);
            SpeechToText.locales().then((result) => {
                console.log(`locales ${result}`);
            });
            SpeechToText.initialize().then((result) => {
                if (result.available == false) {
                    // SpeechToText.initialize().then((available) => {
                    //     if (available) {
                    //         this.initIosRecognizer();
                    //     }
                    // });
                    console.log("speech not available");
                } else {
                    this.initIosRecognizer();
                }
            });
        }
    },

    initIosRecognizer() {
        let self = this;
        SpeechToText.addListener("textRecognition", (data) => {
            console.log("Listener");
            const json = JSON.parse(data.speechString);
            console.log("textRecognition", json.alternates[0].recognizedWords);
            // if (json && json.isFinal) {
                self.final_transcript = json.alternates[0].recognizedWords;
                console.log(self.final_transcript);
                if (self.doneRecognizingTimer != null) {
                    window.clearTimeout(self.doneRecognizingTimer);
                }
                self.doneRecognizingTimer = window.setTimeout(() => {
                    self.doneRecognizingTimer = null;
                    SpeechToText.stop().then(() => {
                        if (json.finalResult) {
                            EventBus.publish("audio-capture:done", self.final_transcript);
                        }
                        EventBus.publish("listening:stop");
                    });
                }, MS_OF_SILENCE_TO_ALLOW_BEFORE_PROCESSING);
            // }
        });

        SpeechToText.addListener("notifyStatus", (data) => {
            console.log(`notifyStatus: ${data}`)
        });

        SpeechToText.addListener("notifyError", (data) => {
            console.log(`notifyError: ${data}`)
        });

        // SpeechToText.addListener("soundLevelChange", (data) => {
        //     console.log(`soundLevelChange: ${data.soundLevel}`)
        // });
    },

    doneRecognizingTimer: null,

    /**
     * This method does not work, because the plugin is broken. This is why we need a new one
     * created, and this is where that plugin should be instantiated and used. Thank you!
     * @returns 
     */
    startIosRecognizer() {
        if (this.listening) return;
        this.recognition_engine = SpeechToText;
        try {
            SpeechToText.listen({
                // language: "en-US",
                // maxResults: 2,
                onDevice: false,
                partialResults: true,
                sampleRate: 0,
                listenMode: ListenMode.confirmation
            }).then((data) => {
                console.log("listen result: " + data)
            }).catch(err => {
                console.log("E: ", err);
            }).finally(() => {
                console.log("Finally");
            });
        } catch (ex) {
            console.log("caught ", ex);
        }
        this.listening = true;
    },

    /**
     * Please do not modify this function, this is the speech recognizer used on desktop/browser
     * and it works well. It just doesn't work on iOS because on iOS, there is a very long delay
     * after you stop talking before we get the transcribed text back.
     * @returns 
     */
    startHtml5Recognizer() {
        if (!('webkitSpeechRecognition' in window)) {
            alert("No speech recognition API available.");
            return;
        }

        if (this.recognition_engine == null) {
            this.recognition_engine = new webkitSpeechRecognition();
            this.recognition_engine.continuous = true;
            this.recognition_engine.interimResults = true;
            this.recognition_engine.lang = "en_US";

            var self = this;
            this.recognition_engine.onstart = function () {
                self.listening = true;
                self.started_listening_at = Date.now();
                EventBus.publish("audio-capture:start");
            };

            this.recognition_engine.onerror = function (event) {
                if (event.error == 'no-speech') {
                    // This is ok, user is just not talking.        
                    self.ignore_onend = true;
                }
                if (event.error == 'audio-capture') {
                    alert("Error: No microphone available. Please connect a microphone and try again.");
                    self.ignore_onend = true;
                }
                if (event.error == 'not-allowed') {
                    if (event.timeStamp - self.start_timestamp < 100) {
                        alert("Speech to text not allowed");
                    } else {
                        alert("Speech to text access denied");
                    }
                    self.ignore_onend = true;
                }
            };

            this.recognition_engine.onend = () => {
                console.log("On end");
                self.listening = false;
                if (self.ignore_onend) {
                    return;
                }                
                EventBus.publish("audio-capture:done", self.final_transcript);
                self.final_transcript = '';
            };

            this.recognition_engine.onresult = (event) => {
                var interim_transcript = '';
                if (typeof (event.results) == 'undefined') {
                    self.recognition_engine.onend = null;
                    console.log("Stopping");
                    self.recognition_engine.stop();
                    self.recognition_engine = false;
                    console.log("Done done");
                    EventBus.publish("audio-capture:done", util.capitalize(self.final_transcript));
                    self.final_transcript = '';
                    return;
                }
                for (var i = event.resultIndex; i < event.results.length; ++i) {
                    if (event.results[i].isFinal) {
                        self.final_transcript += event.results[i][0].transcript;
                        console.log("Still going");
                        EventBus.publish("audio-capture:done", util.capitalize(self.final_transcript));
                        self.final_transcript = '';
                    } else {
                        self.interim_transcript += event.results[i][0].transcript;
                    }
                }

                self.final_transcript = util.capitalize(self.final_transcript);
            };
        }

        this.recognition_engine.start();
        this.ignore_onend = true;
    }

}