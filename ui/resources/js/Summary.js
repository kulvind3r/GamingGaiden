let gamingData = [];
let chart;
let finishedCount = 0;
let inProgressCount = 0;

$('table')[0].setAttribute('id', 'data-table');

// Create custom log axis in base 2
class Log2Axis extends Chart.Scale {
    constructor(cfg) {
        super(cfg);
        this._startValue = undefined;
        this._valueRange = 0;
    }

    parse(raw, index) {
        const value = Chart.LinearScale.prototype.parse.apply(this, [raw, index]);
        return isFinite(value) && value > 0 ? value : null;
    }

    determineDataLimits() {
        const {
            min,
            max
        } = this.getMinMax(true);
        this.min = isFinite(min) ? Math.max(0, min) : null;
        this.max = isFinite(max) ? Math.max(0, max) : null;
    }

    buildTicks() {
        const ticks = [];

        let power = Math.floor(Math.log2(this.min || 1));
        let maxPower = Math.ceil(Math.log2(this.max || 2));
        while (power <= maxPower) {
            ticks.push({
                value: Math.pow(2, power)
            });
            power += 1;
        }

        this.min = ticks[0].value;
        this.max = ticks[ticks.length - 1].value;
        return ticks;
    }

    /**
     * @protected
     */
    configure() {
        const start = this.min;

        super.configure();

        this._startValue = Math.log2(start);
        this._valueRange = Math.log2(this.max) - Math.log2(start);
    }

    getPixelForValue(value) {
        if (value === undefined || value === 0) {
            value = this.min;
        }

        return this.getPixelForDecimal(value === this.min ? 0 :
            (Math.log2(value) - this._startValue) / this._valueRange);
    }

    getValueForPixel(pixel) {
        const decimal = this.getDecimalForPixel(pixel);
        return Math.pow(2, this._startValue + decimal * this._valueRange);
    }
}

Log2Axis.id = 'log2';
Log2Axis.defaults = {};

Chart.register(Log2Axis);

function updateChart() {

    const ctx = document.getElementById('session-vs-playtime-chart').getContext('2d');

    chart = new Chart(ctx, {
        type: 'scatter',
        data: {
            labels: gamingData.map(row => row.name),
            datasets: [{
                data: gamingData.map(row => ({ x: row.sessions, y: row.playtime, completed: row.completed })),
                borderWidth: 2,
                pointBackgroundColor: function (context) {
                    var index = context.dataIndex;
                    var value = context.dataset.data[index].completed;
                    return value == 'FALSE' ? '#ffb1bf' : '#9ad0f5'
                },
                pointBorderColor: function (context) {
                    var index = context.dataIndex;
                    var value = context.dataset.data[index].completed;
                    return value == 'FALSE' ? '#ff6481' : '#36a2eb'
                }
            }]
        },
        options: {
            scales: {
                y: {
                    type: 'log2',
                    title: {
                        display: true,
                        text: "PlayTime (Hours)",
                        font: {
                            size: 18,
                            family: 'monospace'
                        }
                    }
                },
                // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
                // Then hide the right side scale by setting ticks and title color identical to background.
                yRight: {
                    type: 'log2',
                    position: 'right',
                    grid: {
                        display: false
                    },
                    title: {
                        display: true,
                        text: "PlayTime (Hours)",
                        font: {
                            size: 18,
                            family: 'monospace',
                        },
                        color: 'white'
                    },
                    ticks: {
                        color: 'white'
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: "Game Sessions",
                        font: {
                            size: 18,
                            family: 'monospace'
                        }
                    },
                    ticks: {
                        stepSize: 10
                    }
                }
            },
            responsive: true,
            plugins: {
                tooltip: {
                    enabled: true,
                    mode: "nearest",
                    caretPadding: 7,
                    displayColors: false,
                    callbacks: {
                        label: function (context) {
                            label = context.parsed.y + ' hrs over ' + context.parsed.x + ' sessions'
                            return label
                        }
                    }
                },
                legend: {
                    display: false,
                }
            },
            maintainAspectRatio: true
        }
    });
}

function loadDataFromTable() {
    const table = document.getElementById('data-table');
    const rows = table.querySelectorAll('tbody tr');

    gamingData = Array.from(rows).map(row => {
        const name = row.cells[0].textContent;
        const playtime = (parseFloat(row.cells[1].textContent) / 60).toFixed(1);
        const sessions = parseFloat(row.cells[2].textContent)
        const completed = row.cells[3].textContent

        completed == 'FALSE' ? inProgressCount++ : finishedCount++

        return { name, playtime, sessions, completed };
    });

    // Remove header row data, deduct one extra game added to finished count due to header row
    gamingData.shift(); finishedCount--;

    document.getElementById("progress-count").innerText = inProgressCount + ' Games In Progress'
    document.getElementById("finished-count").innerText = finishedCount + ' Games Finished'
    updateChart();
}

loadDataFromTable();
