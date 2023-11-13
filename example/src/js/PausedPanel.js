import EventBus from 'eventing-bus';

export class PausedPanel extends HTMLElement {

  constructor() {
    super();
    this.beginHandler = this.click_handler.bind(this);
  }

  connectedCallback() {
    this.innerHTML = this.template;
    this.querySelector("#start_listening").addEventListener("click", this.beginHandler);
  }

  disconnectedCallback() {
    this.querySelector("#start_listening").removeEventListener("click", this.beginHandler);
  }

  click_handler() {
    EventBus.publish("listening:start");
  }

  get template() {
    return `
      <div id="paused" class="panel visible">
      <table class="page">
        <tr>
          <td>
            <div class="message" id="message">
              Listening paused
            </div>
            <button class="btn resume" id="start_listening">Begin Listening</button>
          </td>
        </tr>
      </table>
  
    </div>      
  `;
  }
}

// What is the difference between these two methods?
window.customElements.define('paused-panel', PausedPanel);
