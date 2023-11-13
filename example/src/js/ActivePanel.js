import EventBus from 'eventing-bus';

export class ActivePanel extends HTMLElement {

    constructor() {
        super();
        this.stopHandler = this.click_stop.bind(this);
    }
  
    connectedCallback() {
      this.innerHTML = this.template;
      this.querySelector("#stop_listening").addEventListener("click", this.stopHandler);
    }
  
    disconnectedCallback() {
      this.querySelector("#stop_listening").removeEventListener("click", this.stopHandler);
    }
    
    click_stop() {
      EventBus.publish("listening:stop");
    }

    get template() {
        return `
        <style>
        .boxContainer {
          display: flex;
          margin: 0px auto;
          margin-bottom: 20px;
          justify-content: space-between;
          height: 64px;
          --boxSize: 8px;
          --gutter: 4px;
          width: calc((var(--boxSize) + var(--gutter)) * 5);
        }
      
        .box {
          transform: scaleY(0.4);
          height: 100%;
          width: var(--boxSize);
          background: #12E2DC;
          -webkit-animation-duration: 1.2s;
          animation-duration: 1.2s;
          -webkit-animation-timing-function: ease-in-out;
          animation-timing-function: ease-in-out;
          -webkit-animation-iteration-count: infinite;
          animation-iteration-count: infinite;
          border-radius: 8px;
        }
      
        .box1 {
          -webkit-animation-name: quiet;
          animation-name: quiet;
        }
      
        .box2 {
          -webkit-animation-name: normal;
          animation-name: normal;
        }
      
        .box3 {
          -webkit-animation-name: quiet;
          animation-name: quiet;
        }
      
        .box4 {
          -webkit-animation-name: loud;
          animation-name: loud;
        }
      
        .box5 {
          -webkit-animation-name: quiet;
          animation-name: quiet;
        }
      
        </style>

        <div id="active" class="panel">
        <table class="page">
          <tr>
            <td>
              <div class="message" id="message">

              </div>
    
              <div class="boxContainer">
                <div class="box box1"></div>
                <div class="box box2"></div>
                <div class="box box3"></div>
                <div class="box box4"></div>
                <div class="box box5"></div>
              </div>
    
              <button class="btn pause" id="stop_listening">Stop Listening</button>
            </td>
          </tr>
        </table>
    
      </div>          

        `;
    }
  }
  
  window.customElements.define('active-panel', ActivePanel);
  