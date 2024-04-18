let gamingData = [];
let chart;

$('table')[0].setAttribute('id','data-table');

function updateChart() {

    const ctx = document.getElementById('session-vs-playtime-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'scatter',
        data: {
            labels: gamingData.map(row => row.name),
            datasets: [{
                data: gamingData.map(row => ({x:row.sessions, y:row.playtime})),
                borderWidth: 2,
            }]
        },
        options: {
            scales: {
                y: {
                    title: {
                        display: true,
                        text: "PlayTime (Hours)",
                        font: {
                            size: 18,
                            family: 'monospace'
                        }
                    },
                    ticks: {
                        stepSize: 10
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
                        stepSize: 5
                    }
                }
            },
            elements: {
                bar: {
                    borderWidth: 1,
                }
            },
            responsive: true, // Make the chart responsive
            plugins: {
                tooltip: {
                    enabled: true,
                    mode: "nearest",
                    displayColors: false,
                    callbacks: {
                        label: function(context) {
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

        return { name, playtime, sessions };
    });

    // Remove header row data
    gamingData.shift()

    updateChart();
}

loadDataFromTable();
