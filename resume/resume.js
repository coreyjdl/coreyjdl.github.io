
'use strict';

const e = React.createElement;

class Resume extends React.Component {
    constructor(props) {
        super(props);
        this.state = { resume: null };
    }

    componentDidMount() {
        fetch('resume.json')
            .then(response => response.json())
            .then(data => this.setState({ resume: data }));
    }

    render() {
        if (!this.state.resume) {
            return e('div', null, 'Loading...');
        }

        const resume = this.state.resume;
        return e('div', { className: 'container' },
            e('div', { className: 'card' },
                e('div', { className: 'card-body' },
                    e('h1', null, resume.Name),
                    e('h2', null, resume['Current Title']),
                    e('p', null, resume['Professional Summary'])
                )
            ),
            e('div', { className: 'card' },
                e('div', { className: 'card-body' },
                    e('h3', null, 'Technical Skills'),
                    e('ul', null,
                        ...Object.keys(resume).filter(key => Array.isArray(resume[key]) && key !== 'Work History' && key !== 'Professional Summary').map(key =>
                            e('li', null, e('strong', null, key + ': '), resume[key].join(', '))
                        )
                    )
                )
            ),
            e('div', { className: 'card' },
                e('div', { className: 'card-body' },
                    e('h3', null, 'Work History'),
                    e('ul', null,
                        resume['Work History'].map(job =>
                            e('li', { key: job.Title + job.Company },
                                e('h4', null, job.Title + ' at ' + job.Company),
                                e('p', null, job['Company Description']),
                                e('p', null, job['Start Date'] + ' - ' + job['End Date']),
                                e('ul', null,
                                    job['Description of Work'].map(desc => e('li', { key: desc }, desc))
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}

const domContainer = document.querySelector('#resume');
ReactDOM.render(e(Resume), domContainer);