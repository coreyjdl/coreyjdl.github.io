
'use strict';

const e = React.createElement;

class Resume extends React.Component {
    render() {
        return "TEST TEST TEST";
    }
}

const domContainer = document.querySelector('#resume');
ReactDOM.render(e(Resume), domContainer);