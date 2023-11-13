export default {

    showElement(e) {
        document.getElementById(e).classList.add("visible");
    },

    hideElement(e) {
        var c = document.getElementById(e).classList;
        if (c) c.remove("visible");
    },
    randomFloat(min, max) {
        return Math.random() * (max - min) + min;
    },
    uuidv4() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    },
    linebreak(s) {
        var two_line = /\n\n/g;
        var one_line = /\n/g;
        return s.replace(two_line, '<p></p>').replace(one_line, '<br>');
    },
    capitalize(s) {
        var first_char = /\S/;
        return s.replace(first_char, function (m) { return m.toUpperCase(); });
    }

};