export default {

    init() {
        window.startTime = Date.now();
    },

    elapsed() {
        window.endTime = Date.now();
        if (!window.startTime) window.startTime = window.endTime;
        let elapsed = window.endTime - window.startTime;
        window.startTime = window.endTime;
        return elapsed;
    },

    debugTime(message) {
        console.log("[ ELAPSED ] " + message + ": " + this.elapsed() + " ms");
    }
}