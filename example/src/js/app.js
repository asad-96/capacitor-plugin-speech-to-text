import { Capacitor } from '@capacitor/core';
import { SplashScreen } from '@capacitor/splash-screen';
import { ActivePanel } from "./ActivePanel";
import { PausedPanel } from "./PausedPanel";
import EventBus from 'eventing-bus';
import util from "./util"
import audioCapture from './audio-capture';

export class App extends HTMLElement {

    constructor() {
        super();
        SplashScreen.hide();
    }

    /**
     * Called when the "app-main" element (app container) starts up. Here, we
     * attach event handlers for the top-level events, like when AIDA starts
     * listening, stops listening, or is processing input. This is how the animation
     * starts and stops.
     */
    connectedCallback() {
        this.innerHTML = this.template;
        audioCapture.init();
        EventBus.on("listening:stop", this.stopListening);
        EventBus.on("listening:start", this.startListening);
        EventBus.on("audio-capture:done", this.processUserInput);
    }

    processUserInput(textWeHeard) {
        console.log("Processing "+textWeHeard);
        document.getElementById("message").innerHTML = document.getElementById("message").innerHTML + ' ' + textWeHeard;        
    }
    
    stopListening() {
        util.hideElement("active");
        util.showElement("paused");
        audioCapture.stop();
    }

    startListening() {        
        util.hideElement("paused");
        util.showElement("active"); 
        let self = this;
        audioCapture.listen();
    }

    get template() {
        return `
        <paused-panel id="pausedpanel"></paused-panel>
        <active-panel id="activepanel"></active-panel>
        <thinking-panel id="thinkingpanel"></thinking-panel>    
        `;
    }
}

// What is the difference between these two methods?
window.customElements.define('app-main', App);


