let gamingData = [];
let chart;
let finishedCount = 0;
let inProgressCount = 0;

$('table')[0].setAttribute('id','data-table');

function updateChart() {

    const ctx = document.getElementById('session-vs-playtime-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'scatter',
        data: {
            labels: gamingData.map(row => row.name),
            datasets: [{
                data: gamingData.map(row => ({x:row.sessions, y:row.playtime, completed:row.completed})),
                borderWidth: 2,
                pointBackgroundColor: function(context) {
                    var index = context.dataIndex;
                    var value = context.dataset.data[index].completed;
                    return value == 'FALSE' ? '#ffb1bf' : '#9ad0f5'
                },
                pointBorderColor: function(context) {
                    var index = context.dataIndex;
                    var value = context.dataset.data[index].completed;
                    return value == 'FALSE' ? '#ff6481' : '#36a2eb'
                }
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
                // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
                // Then hide the right side scale by setting ticks and title color identical to background.
                yRight: {
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
						color: () => {
                            return window.getComputedStyle(document.body ,null).getPropertyValue('background-color');
                        }
                    },
					ticks: {
                        color: () => {
                            return window.getComputedStyle(document.body ,null).getPropertyValue('background-color');
                        }
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
